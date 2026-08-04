module Admin
  class AnalyticsController < ApplicationController
    include AdminAuthorization

    EXCLUDED_EMAILS = ['atlas@architecturehelper.com', 'cdnathan.robinson@gmail.com'].freeze

    # DAU / WAU / MAU and per-activity engagement, driven by user_events
    def engagement
      @exclude_internal = params[:exclude_internal] != '0'
      excluded_user_ids = @exclude_internal ? User.where(email: EXCLUDED_EMAILS).pluck(:id) : []

      base = UserEvent.all
      base = base.where.not(user_id: excluded_user_ids) if excluded_user_ids.any?
      identified = base.where.not(user_id: nil)

      today_start = Date.current.beginning_of_day
      @dau = identified.where(created_at: today_start..).distinct.count(:user_id)
      @wau = identified.where(created_at: 7.days.ago..).distinct.count(:user_id)
      @mau = identified.where(created_at: 30.days.ago..).distinct.count(:user_id)
      @stickiness = @mau.positive? ? (@dau * 100.0 / @mau).round(1) : 0

      # Anonymous reach for context (sessions without sign-in)
      @sessions_30d = base.where(created_at: 30.days.ago..).where.not(session_id: [nil, '']).distinct.count(:session_id)

      # Daily series, last 30 days (keys normalized: Date on PG, String on SQLite)
      window_start = 29.days.ago.to_date
      normalize = ->(h) { h.transform_keys { |k| k.to_s[0, 10] } }
      events_by_day = normalize.call(base.where('created_at >= ?', window_start.beginning_of_day).group('DATE(created_at)').count)
      users_by_day = normalize.call(identified.where('created_at >= ?', window_start.beginning_of_day).group('DATE(created_at)').distinct.count(:user_id))
      @daily_engagement = (window_start..Date.current).map do |d|
        { date: d.strftime('%b %-d'), events: events_by_day[d.to_s] || 0, users: users_by_day[d.to_s] || 0 }
      end

      # Per-activity breakdown, last 30 days
      window = base.where(created_at: 30.days.ago..)
      totals = window.group(:event_type).count
      uniq_users = window.group(:event_type).distinct.count(:user_id)
      uniq_sessions = window.where.not(session_id: [nil, '']).group(:event_type).distinct.count(:session_id)
      @activity_breakdown = totals.map do |type, count|
        { type: type, events: count, users: uniq_users[type] || 0, sessions: uniq_sessions[type] || 0 }
      end.sort_by { |row| -row[:users] }
    end

    def index
      @exclude_internal = params[:exclude_internal] != '0'
      @timeframe = (params[:timeframe] || '30').to_i
      @start_date = @timeframe.days.ago

      excluded_user_ids = @exclude_internal ? User.where(email: EXCLUDED_EMAILS).pluck(:id) : []

      base = UserEvent.where(created_at: @start_date..)
      base = base.where.not(user_id: excluded_user_ids) if excluded_user_ids.any?

      # === Summary stats ===
      @total_events = base.count
      @unique_sessions = base.where.not(session_id: nil).distinct.count(:session_id)
      @unique_visitors = base.select("DISTINCT COALESCE(ip_hash, session_id)").count
      @registered_actors = base.where.not(user_id: nil).distinct.count(:user_id)

      # === Time series ===
      @events_per_day = base.group("DATE(created_at)").order("DATE(created_at)").count

      @visitors_per_day = base
        .group("DATE(created_at)")
        .select("DATE(created_at) as date, COUNT(DISTINCT COALESCE(ip_hash, session_id)) as cnt")
        .order("DATE(created_at)")
        .map { |e| [e.date, e.cnt] }.to_h

      # === Event breakdown ===
      @event_types = base.group(:event_type).order("count_all DESC").count

      # === Top content ===
      @top_buildings = resolve_buildings(
        base.by_type("building_view")
          .where("metadata->>'building_id' IS NOT NULL")
          .group("metadata->>'building_id'")
          .order("count_all DESC").limit(15).count
      )

      @top_places = resolve_places(
        base.by_type("place_view")
          .where("metadata->>'place_id' IS NOT NULL")
          .group("metadata->>'place_id'")
          .order("count_all DESC").limit(10).count
      )

      @top_pages = base.by_type("page_view")
        .where("metadata->>'path' IS NOT NULL")
        .group("metadata->>'path'")
        .order("count_all DESC").limit(20).count

      # === Feature adoption ===
      total_sess = [base.where.not(session_id: nil).distinct.count(:session_id), 1].max
      @feature_adoption = {
        'Building View'    => 'building_view',
        'Place / City'     => 'place_view',
        'Search'           => 'search',
        'Building Submit'  => 'building_submit',
        'Style Browse'     => 'style_browse',
        'Map View'         => 'map_view',
        'Screenshot Tool'  => 'screenshot_analyze',
        'Design Flow'      => 'design_step1',
        'Library Browse'   => 'building_library_view',
        'Profile View'     => 'profile_view',
        'Leaderboard'      => 'leaderboard_view',
        'Dev Estimation'   => 'dev_estimation_view'
      }.map do |label, evt|
        sess = base.by_type(evt).where.not(session_id: nil).distinct.count(:session_id)
        pct = (sess.to_f / total_sess * 100).round(1)
        [label, { sessions: sess, pct: pct }]
      end.sort_by { |_, v| -v[:pct] }

      # === Hourly heatmap ===
      @hourly = base.group("EXTRACT(HOUR FROM created_at)::int").order("extract_hour_from_created_at_int").count

      # === Most active users ===
      @top_users = base.where.not(user_id: nil)
        .joins(:user).group(:user_id, 'users.email')
        .order("count_all DESC").limit(15).count
        .map { |(uid, email), cnt| { email: email, count: cnt, id: uid } }

      # === New user journeys ===
      @new_user_journeys = build_new_user_journeys(base, excluded_user_ids)

      # === Recent sessions ===
      @user_sessions = build_sessions(base, excluded_user_ids)

      # === Live feed ===
      feed = UserEvent.order(created_at: :desc)
      feed = feed.where.not(user_id: excluded_user_ids) if excluded_user_ids.any?
      @recent_events = feed.limit(100).includes(:user)
    end

    private

    def resolve_buildings(id_counts)
      ids = id_counts.keys
      names = BuildingAnalysis.where(id: ids).pluck(:id, :name).to_h
      id_counts.map { |id, cnt| { id: id, name: names[id.to_i] || "##{id}", count: cnt } }
    end

    def resolve_places(id_counts)
      ids = id_counts.keys
      names = Place.where(id: ids).pluck(:id, :name).to_h
      id_counts.map { |id, cnt| { id: id, name: names[id.to_i] || "##{id}", count: cnt } }
    end

    def build_new_user_journeys(base, excluded_user_ids)
      scope = User.where(created_at: @start_date..).order(created_at: :desc).limit(25)
      scope = scope.where.not(id: excluded_user_ids) if excluded_user_ids.any?

      scope.filter_map do |user|
        events = UserEvent.where(user_id: user.id).order(:created_at).limit(50)
          .pluck(:event_type, :created_at, :metadata)
        next if events.empty?

        actions = events.reject { |e| e[0] == 'page_view' }
        pages = events.select { |e| e[0] == 'page_view' }

        {
          email: user.email,
          signed_up: user.created_at,
          total_events: events.size,
          pages: pages.filter_map { |e| e[2]&.dig('path') }.uniq,
          actions: actions.map { |e| e[0] }.tally.sort_by { |_, v| -v },
          last_seen: events.last[1],
          days_active: events.map { |e| e[1].to_date }.uniq.size
        }
      end
    end

    def build_sessions(base, excluded_user_ids)
      recent_sids = base.where.not(session_id: nil)
        .group(:session_id).order("MAX(created_at) DESC").limit(30).pluck(:session_id)

      recent_sids.filter_map do |sid|
        evts = UserEvent.where(session_id: sid, created_at: @start_date..)
        evts = evts.where.not(user_id: excluded_user_ids) if excluded_user_ids.any?
        evts = evts.order(:created_at).pluck(:event_type, :created_at, :metadata, :user_id)
        next if evts.empty?

        uid = evts.filter_map { |e| e[3] }.first
        user = uid ? User.find_by(id: uid) : nil

        {
          session_id: sid.to_s.first(8),
          user_email: user&.email || 'anonymous',
          started_at: evts.first[1],
          duration_min: ((evts.last[1] - evts.first[1]) / 60.0).round(1),
          event_count: evts.size,
          events: evts.map { |e| { type: e[0], time: e[1], meta: e[2] } }
        }
      end
    end
  end
end
