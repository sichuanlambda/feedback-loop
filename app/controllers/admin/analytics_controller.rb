module Admin
  class AnalyticsController < ApplicationController
    include AdminAuthorization

    ATLAS_USER_ID = 880

    def index
      @exclude_atlas = params[:exclude_atlas] != '0'
      base = UserEvent.where(created_at: 30.days.ago..)
      base = base.where.not(user_id: ATLAS_USER_ID) if @exclude_atlas

      @events_per_day = base
        .group("DATE(created_at)")
        .order("DATE(created_at)")
        .count

      @top_event_types = base
        .group(:event_type)
        .order("count_all DESC")
        .limit(20)
        .count

      @top_buildings = base
        .by_type("building_view")
        .where("metadata->>'building_id' IS NOT NULL")
        .group("metadata->>'building_id'")
        .order("count_all DESC")
        .limit(10)
        .count

      @top_places = base
        .by_type("place_view")
        .where("metadata->>'place_id' IS NOT NULL")
        .group("metadata->>'place_id'")
        .order("count_all DESC")
        .limit(10)
        .count

      @top_pages = base
        .by_type("page_view")
        .where("metadata->>'path' IS NOT NULL")
        .group("metadata->>'path'")
        .order("count_all DESC")
        .limit(20)
        .count

      @recent_events = UserEvent.order(created_at: :desc)
      @recent_events = @recent_events.where.not(user_id: ATLAS_USER_ID) if @exclude_atlas
      @recent_events = @recent_events.limit(100).includes(:user)

      @unique_visitors_per_day = base
        .group("DATE(created_at)")
        .order("DATE(created_at)")
        .select("DATE(created_at) as date, COUNT(DISTINCT COALESCE(ip_hash, session_id)) as visitor_count")
        .map { |e| [e.date, e.visitor_count] }
        .to_h

      @user_sessions = build_user_sessions(base)
      @new_user_journeys = build_new_user_journeys(base)
      @most_active_users = get_most_active_users(base)
      @feature_adoption = calculate_feature_adoption(base)
      @hourly_activity = base.group("EXTRACT(HOUR FROM created_at)::int").order("extract_hour_from_created_at_int").count
    end

    private

    def build_user_sessions(base)
      # Get recent unique sessions with their full event timeline
      recent_sessions = base
        .select(:session_id)
        .where.not(session_id: nil)
        .group(:session_id)
        .order("MAX(created_at) DESC")
        .limit(30)
        .pluck(:session_id)

      recent_sessions.map do |sid|
        events = UserEvent.where(session_id: sid, created_at: 30.days.ago..)
        events = events.where.not(user_id: ATLAS_USER_ID) if @exclude_atlas
        events = events.order(:created_at)
          .pluck(:event_type, :created_at, :metadata, :user_id)

        next if events.empty?

        user_id = events.map { |e| e[3] }.compact.first
        user = user_id ? User.find_by(id: user_id) : nil

        {
          session_id: sid.to_s.first(8),
          user_email: user&.email || 'anonymous',
          user_id: user_id,
          started_at: events.first[1],
          duration_min: ((events.last[1] - events.first[1]) / 60.0).round(1),
          event_count: events.size,
          events: events.map { |e| { type: e[0], time: e[1], meta: e[2] } }
        }
      end.compact
    end

    def build_new_user_journeys(base)
      # Find users who signed up in last 30 days and trace their first session
      new_users = User.where(created_at: 30.days.ago..).order(created_at: :desc).limit(20)
      
      new_users.map do |user|
        events = UserEvent.where(user_id: user.id)
          .order(:created_at)
          .limit(50)
          .pluck(:event_type, :created_at, :metadata)

        next if events.empty?

        action_events = events.reject { |e| e[0] == 'page_view' }
        page_events = events.select { |e| e[0] == 'page_view' }

        {
          email: user.email,
          signed_up: user.created_at,
          total_events: events.size,
          pages_visited: page_events.map { |e| e[2]['path'] }.compact.uniq,
          actions_taken: action_events.map { |e| e[0] }.tally.sort_by { |_, v| -v },
          last_seen: events.last[1],
          days_active: events.map { |e| e[1].to_date }.uniq.size
        }
      end.compact
    end

    def get_most_active_users(base)
      base
        .where.not(user_id: nil)
        .joins(:user)
        .group(:user_id, 'users.email')
        .order("count_all DESC")
        .limit(15)
        .count
        .map { |(user_id, email), count| { email: email, event_count: count, user_id: user_id } }
    end

    def calculate_feature_adoption(base)
      total_sessions = base.distinct.count(:session_id)
      return {} if total_sessions == 0

      features = {
        'Building View' => 'building_view',
        'Building Submit' => 'building_submit',
        'Style Browse' => 'style_browse',
        'Map View' => 'map_view',
        'Screenshot Analyze' => 'screenshot_analyze',
        'Design Flow' => 'design_step1',
        'Place View' => 'place_view',
        'Profile View' => 'profile_view',
        'Search' => 'search',
        'Library Browse' => 'building_library_view',
        'Leaderboard' => 'leaderboard_view',
        'Dev Estimation' => 'dev_estimation_view'
      }

      features.map do |label, event_type|
        sessions = base.by_type(event_type).distinct.count(:session_id)
        [label, { sessions: sessions, pct: (sessions.to_f / total_sessions * 100).round(1) }]
      end.to_h
    end
  end
end
