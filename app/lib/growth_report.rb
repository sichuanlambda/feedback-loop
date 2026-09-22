# Aggregates the growth funnel for /admin/growth from the first-party
# user_events table: human traffic only (see UserEvent.human), where visitors
# come from, which pages they land on, the upload funnel, device split, and
# CTA/email counts. Written to run on both Postgres (production) and SQLite
# (development and test), which is why JSON access and week bucketing branch
# on the adapter.
class GrowthReport
  SEARCH_REFERRERS = %w[google. bing.com duckduckgo yahoo. ecosia brave.com yandex baidu startpage qwant].freeze
  AI_REFERRERS = %w[chatgpt openai perplexity claude.ai gemini.google copilot grokipedia].freeze
  SOCIAL_REFERRERS = %w[facebook instagram t.co twitter x.com reddit pinterest linkedin youtube tiktok].freeze
  TOOL_EVENTS = %w[analysis_started guest_analysis_started restyle_submit restyle_guest_started design_submit].freeze
  ANALYSIS_START_EVENTS = %w[analysis_started guest_analysis_started].freeze
  DEVICE_CASE = "CASE WHEN user_agent LIKE '%iPad%' THEN 'tablet' " \
                "WHEN user_agent LIKE '%iPhone%' OR (user_agent LIKE '%Android%' AND user_agent LIKE '%Mobile%') THEN 'mobile' " \
                "WHEN user_agent LIKE '%Android%' THEN 'tablet' ELSE 'desktop' END".freeze

  def initialize(days: 30, exclude_user_ids: [])
    @days = days
    @now = Time.current
    @window = (@now - days.days)..@now
    @previous = (@now - (2 * days).days)...(@now - days.days)
    @base = UserEvent.human
    # where.not(user_id: ids) would also drop every signed-out row (NULL user_id)
    @base = @base.where('user_id IS NULL OR user_id NOT IN (?)', exclude_user_ids) if exclude_user_ids.any?
    @pageviews = @base.where(event_type: 'page_view')
  end

  def build
    {
      days: @days,
      kpis: kpis,
      weekly: weekly,
      sources: sources,
      landing: landing_pages,
      funnel: funnel,
      devices: devices,
      clicks: clicks
    }
  end

  private

  def pg?
    UserEvent.connection.adapter_name.match?(/postg/i)
  end

  def md(key)
    pg? ? "metadata->>'#{key}'" : "json_extract(metadata, '$.#{key}')"
  end

  def week_expr
    pg? ? "date_trunc('week', created_at)" : "strftime('%Y-%W', created_at)"
  end

  def ref_like(terms)
    '(' + terms.map { |t| "#{md('referrer')} LIKE '%#{t}%'" }.join(' OR ') + ')'
  end

  # Google OAuth returns visitors via accounts.google.com; that is not a search
  def search_ref
    "#{ref_like(SEARCH_REFERRERS)} AND #{md('referrer')} NOT LIKE '%accounts.google.%'"
  end

  def external_ref
    "#{md('referrer')} IS NOT NULL AND #{md('referrer')} <> '' AND #{md('referrer')} NOT LIKE '%architecturehelper.com%'"
  end

  def users_in(win)
    User.where(created_at: win).where.not(email: User::GUEST_EMAIL)
  end

  def sessions(scope)
    scope.distinct.count(:session_id)
  end

  def engaged_sessions(win)
    sub = @pageviews.where(created_at: win).select(:session_id).group(:session_id).having('COUNT(*) >= 2')
    UserEvent.connection.select_value("SELECT COUNT(*) FROM (#{sub.to_sql}) engaged").to_i
  end

  def kpi_set(win)
    {
      sessions: sessions(@pageviews.where(created_at: win)),
      engaged: engaged_sessions(win),
      search: sessions(@pageviews.where(created_at: win).where(search_ref)),
      signups: users_in(win).count,
      tools: sessions(@base.where(event_type: TOOL_EVENTS, created_at: win))
    }
  end

  def kpis
    { current: kpi_set(@window), previous: kpi_set(@previous), paying: User.where(subscription_status: 'active').count }
  end

  def weekly
    since = (@now - 12.weeks).beginning_of_week
    rows = Hash.new { |h, k| h[k] = { search: 0, external: 0, signups: 0, tools: 0 } }
    add = ->(key, counts) { counts.each { |week, n| rows[week_label(week)][key] = n } }

    add.call(:search, @pageviews.where('created_at >= ?', since).where(search_ref).group(Arel.sql(week_expr)).distinct.count(:session_id))
    add.call(:external, @pageviews.where('created_at >= ?', since).where(external_ref).group(Arel.sql(week_expr)).distinct.count(:session_id))
    add.call(:tools, @base.where(event_type: TOOL_EVENTS).where('created_at >= ?', since).group(Arel.sql(week_expr)).distinct.count(:session_id))
    add.call(:signups, users_in(since..@now).group(Arel.sql(week_expr)).count)

    rows.sort.map { |week, counts| counts.merge(week: week) }
  end

  def week_label(week)
    week.respond_to?(:strftime) ? week.strftime('%Y-%m-%d') : week.to_s
  end

  def sources
    counts = @pageviews.where(created_at: @window).where(external_ref)
                       .group(Arel.sql(md('referrer'))).distinct.count(:session_id)
    by_host = Hash.new(0)
    counts.each do |ref, n|
      host = begin
        URI.parse(ref.to_s.strip).host || ref.to_s
      rescue URI::Error
        ref.to_s
      end
      by_host[host.to_s.sub(/\Awww\./, '')] += n
    end
    by_host.map { |host, n| { host: host, sessions: n, kind: classify(host) } }
           .sort_by { |r| -r[:sessions] }.first(25)
  end

  def classify(host)
    return 'auth' if host.start_with?('accounts.')
    return 'search' if SEARCH_REFERRERS.any? { |t| host.include?(t) }
    return 'ai' if AI_REFERRERS.any? { |t| host.include?(t) }
    return 'social' if SOCIAL_REFERRERS.any? { |t| host.include?(t) }

    'other'
  end

  def landing_pages
    @pageviews.where(created_at: @window).where(search_ref)
              .group(Arel.sql(md('path'))).distinct.count(:session_id)
              .sort_by { |_, n| -n }.first(20)
              .map { |path, n| { path: path, sessions: n } }
  end

  def funnel
    win = @base.where(created_at: @window)
    {
      form_views: sessions(win.where(event_type: 'building_new_form')),
      photo_selected: sessions(win.where(event_type: 'upload_photo_selected')),
      analyses_started: sessions(win.where(event_type: ANALYSIS_START_EVENTS)),
      restyle_views: sessions(win.where(event_type: 'restyle_view')),
      restyles_started: sessions(win.where(event_type: %w[restyle_submit restyle_guest_started])),
      signups: users_in(@window).count,
      activated: users_in(@window).where(
        'EXISTS (SELECT 1 FROM building_analyses b WHERE b.user_id = users.id) ' \
        'OR EXISTS (SELECT 1 FROM arch_image_gens g WHERE g.user_id = users.id)'
      ).count,
      new_paying: users_in(@window).where(subscription_status: 'active').count
    }
  end

  def devices
    per_session = ->(scope) { scope.group(Arel.sql(DEVICE_CASE)).distinct.count(:session_id) }
    sessions = per_session.call(@pageviews.where(created_at: @window))
    tools = per_session.call(@base.where(event_type: TOOL_EVENTS, created_at: @window))
    signups = @base.where(event_type: 'user_signup', created_at: @window).group(Arel.sql(DEVICE_CASE)).count

    %w[desktop mobile tablet].map do |d|
      { device: d, sessions: sessions[d].to_i, tools: tools[d].to_i, signups: signups[d].to_i }
    end
  end

  def clicks
    win = @base.where(created_at: @window)
    {
      blog_cta: win.where(event_type: 'blog_cta_click').group(Arel.sql("COALESCE(#{md('placement')}, 'end')")).count,
      restyle_cta: win.where(event_type: 'restyle_cta_click').count,
      checkout: win.where(event_type: 'checkout_click').count,
      reminders_sent: win.where(event_type: 'credit_reminder_sent').count,
      reminder_visits: sessions(win.where(event_type: 'page_view').where("#{md('params')} LIKE '%credit_reminder_email%'")),
      pricing_by_src: win.where(event_type: 'pricing_view').group(Arel.sql("COALESCE(#{md('src')}, '(none)')")).count
                         .sort_by { |_, n| -n }.first(8)
    }
  end
end
