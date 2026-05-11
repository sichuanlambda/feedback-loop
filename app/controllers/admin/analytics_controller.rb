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
        .limit(10)
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
    end
  end
end
