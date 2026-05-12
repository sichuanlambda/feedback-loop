module Admin
  class AnalyticsController < ApplicationController
    include AdminAuthorization

    def index
      @events_per_day = UserEvent.where(created_at: 30.days.ago..)
        .group("DATE(created_at)")
        .order("DATE(created_at)")
        .count

      @top_event_types = UserEvent.recent
        .group(:event_type)
        .order("count_all DESC")
        .limit(15)
        .count

      @top_buildings = UserEvent.recent
        .by_type("building_view")
        .where("metadata->>'building_id' IS NOT NULL")
        .group("metadata->>'building_id'")
        .order("count_all DESC")
        .limit(10)
        .count

      @top_places = UserEvent.recent
        .by_type("place_view")
        .where("metadata->>'place_id' IS NOT NULL")
        .group("metadata->>'place_id'")
        .order("count_all DESC")
        .limit(10)
        .count

      @recent_events = UserEvent.order(created_at: :desc).limit(100).includes(:user)

      @unique_visitors_per_day = UserEvent.where(created_at: 30.days.ago..)
        .group("DATE(created_at)")
        .order("DATE(created_at)")
        .select("DATE(created_at) as date, COUNT(DISTINCT COALESCE(ip_hash, session_id)) as visitor_count")
        .map { |e| [e.date, e.visitor_count] }
        .to_h

      # Enhanced analytics
      @user_journey_funnels = calculate_user_journey_funnels
      @most_active_users = get_most_active_users
      @feature_adoption_rates = calculate_feature_adoption_rates
      @client_vs_server_events = get_client_vs_server_breakdown
      @conversion_metrics = calculate_conversion_metrics
    end

    private

    def calculate_user_journey_funnels
      # Analyze user progression through key actions
      recent_sessions = UserEvent.where(created_at: 30.days.ago..)
        .distinct(:session_id)
        .pluck(:session_id)

      funnel_data = {}
      
      recent_sessions.each do |session_id|
        events = UserEvent.where(session_id: session_id, created_at: 30.days.ago..)
          .order(:created_at)
          .pluck(:event_type)
        
        # Track key progression points
        has_view = events.include?('building_view') || events.include?('place_view')
        has_analyze = events.include?('analysis_started') || events.include?('screenshot_analyze')
        has_submit = events.include?('building_submit') || events.include?('feedback_submit')
        
        stage = if has_submit
                  'submit'
                elsif has_analyze
                  'analyze'
                elsif has_view
                  'view'
                else
                  'visitor'
                end
        
        funnel_data[stage] = (funnel_data[stage] || 0) + 1
      end
      
      funnel_data
    end

    def get_most_active_users
      UserEvent.recent
        .where.not(user_id: nil)
        .joins(:user)
        .group(:user_id, 'users.email')
        .order("count_all DESC")
        .limit(10)
        .count
        .map { |(user_id, email), count| { email: email, event_count: count } }
    end

    def calculate_feature_adoption_rates
      total_users = UserEvent.recent.distinct(:user_id).count(:user_id)
      return {} if total_users == 0

      feature_events = [
        'building_submit',
        'design_step1',
        'screenshot_analyze',
        'profile_view',
        'style_browse',
        'map_view'
      ]

      adoption_rates = {}
      feature_events.each do |event_type|
        users_using_feature = UserEvent.recent
          .by_type(event_type)
          .distinct(:user_id)
          .count(:user_id)
        
        adoption_rates[event_type] = {
          users: users_using_feature,
          percentage: (users_using_feature.to_f / total_users * 100).round(1)
        }
      end

      adoption_rates
    end

    def get_client_vs_server_breakdown
      client_side = UserEvent.recent
        .where("metadata->>'client_side' = 'true'")
        .count

      server_side = UserEvent.recent
        .where("metadata->>'client_side' IS NULL OR metadata->>'client_side' != 'true'")
        .count

      {
        client_side: client_side,
        server_side: server_side,
        total: client_side + server_side
      }
    end

    def calculate_conversion_metrics
      # Calculate conversion from views to submissions
      building_views = UserEvent.recent.by_type('building_view').count
      building_submissions = UserEvent.recent.by_type('building_submit').count
      
      place_views = UserEvent.recent.by_type('place_view').count
      place_subscriptions = UserEvent.recent.by_type('place_subscribe').count

      design_starts = UserEvent.recent.by_type('design_step1').count
      design_completions = UserEvent.recent.by_type('design_submit').count

      {
        building_conversion: building_views > 0 ? (building_submissions.to_f / building_views * 100).round(2) : 0,
        place_conversion: place_views > 0 ? (place_subscriptions.to_f / place_views * 100).round(2) : 0,
        design_completion: design_starts > 0 ? (design_completions.to_f / design_starts * 100).round(2) : 0
      }
    end
  end
end
