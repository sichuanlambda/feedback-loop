class Admin::DashboardController < ApplicationController
  include AdminAuthorization

  def index
    # Basic statistics
    @total_buildings = BuildingAnalysis.count
    @visible_buildings = BuildingAnalysis.where(visible_in_library: true).count
    @hidden_buildings = BuildingAnalysis.where(visible_in_library: false).count
    @total_users = User.count
    @total_arch_images = ArchImageGen.count
    
    # Time-based statistics (last 30 days)
    thirty_days_ago = 30.days.ago
    
    # New users in last 30 days
    @new_users_30_days = User.where('created_at >= ?', thirty_days_ago).count
    @new_users_7_days = User.where('created_at >= ?', 7.days.ago).count
    @new_users_today = User.where('created_at >= ?', Date.current.beginning_of_day).count
    
    # Active users (users who have submitted buildings in last 30 days)
    @active_users_30_days = User.joins(:building_analyses)
                                .where('building_analyses.created_at >= ?', thirty_days_ago)
                                .distinct.count
    
    # Buildings submitted in last 30 days
    @buildings_30_days = BuildingAnalysis.where('created_at >= ?', thirty_days_ago).count
    @buildings_7_days = BuildingAnalysis.where('created_at >= ?', 7.days.ago).count
    @buildings_today = BuildingAnalysis.where('created_at >= ?', Date.current.beginning_of_day).count
    
    # Tour statistics (based on places with building analyses)
    @total_places = Place.count
    
    # Calculate virtual tour potential (places with 3+ buildings)
    @places_virtual_tour_ready = 0
    @places_physical_tour_ready = 0
    
    Place.find_each do |place|
      buildings_in_place = place.building_analyses_in_place
      if buildings_in_place.count >= 3
        @places_virtual_tour_ready += 1
        
        # Check if buildings have coordinates for physical tours
        buildings_with_coords = buildings_in_place.where.not(latitude: nil, longitude: nil)
        if buildings_with_coords.count >= 3
          @places_physical_tour_ready += 1
        end
      end
    end
    
    # Recent activity
    @recent_buildings = BuildingAnalysis.includes(:user).order(created_at: :desc).limit(5)
    @recent_users = User.order(created_at: :desc).limit(5)
    
    # Style statistics
    @style_counts = BuildingAnalysis.where(visible_in_library: true)
                                   .pluck(:h3_contents)
                                   .compact
                                   .flat_map { |content| JSON.parse(content) rescue [] }
                                   .tally
                                   .sort_by { |_, count| -count }
                                   .first(10)
    
    # User engagement metrics
    @users_with_buildings = User.joins(:building_analyses).distinct.count
    @avg_buildings_per_user = @users_with_buildings > 0 ? (@total_buildings.to_f / @users_with_buildings).round(1) : 0
    
    # Growth trends (last 7 days vs previous 7 days)
    seven_days_ago = 7.days.ago
    fourteen_days_ago = 14.days.ago
    
    @users_last_7_days = User.where('created_at >= ?', seven_days_ago).count
    @users_previous_7_days = User.where('created_at >= ? AND created_at < ?', fourteen_days_ago, seven_days_ago).count
    @user_growth_rate = @users_previous_7_days > 0 ? ((@users_last_7_days - @users_previous_7_days).to_f / @users_previous_7_days * 100).round(1) : 0
    
    @buildings_last_7_days = BuildingAnalysis.where('created_at >= ?', seven_days_ago).count
    @buildings_previous_7_days = BuildingAnalysis.where('created_at >= ? AND created_at < ?', fourteen_days_ago, seven_days_ago).count
    @building_growth_rate = @buildings_previous_7_days > 0 ? ((@buildings_last_7_days - @buildings_previous_7_days).to_f / @buildings_previous_7_days * 100).round(1) : 0
  end

  def analytics
    # Basic statistics
    @total_buildings = BuildingAnalysis.count
    @visible_buildings = BuildingAnalysis.where(visible_in_library: true).count
    @hidden_buildings = BuildingAnalysis.where(visible_in_library: false).count
    @total_users = User.count
    @total_arch_images = ArchImageGen.count
    
    # Time-based statistics (last 30 days)
    thirty_days_ago = 30.days.ago
    
    # New users in last 30 days
    @new_users_30_days = User.where('created_at >= ?', thirty_days_ago).count
    @new_users_7_days = User.where('created_at >= ?', 7.days.ago).count
    @new_users_today = User.where('created_at >= ?', Date.current.beginning_of_day).count
    
    # Active users (users who have submitted buildings in last 30 days)
    @active_users_30_days = User.joins(:building_analyses)
                                .where('building_analyses.created_at >= ?', thirty_days_ago)
                                .distinct.count
    
    # Buildings submitted in last 30 days
    @buildings_30_days = BuildingAnalysis.where('created_at >= ?', thirty_days_ago).count
    @buildings_7_days = BuildingAnalysis.where('created_at >= ?', 7.days.ago).count
    @buildings_today = BuildingAnalysis.where('created_at >= ?', Date.current.beginning_of_day).count
    
    # Tour statistics (based on places with building analyses)
    @total_places = Place.count
    
    # Calculate virtual tour potential (places with 3+ buildings)
    @places_virtual_tour_ready = 0
    @places_physical_tour_ready = 0
    
    Place.find_each do |place|
      buildings_in_place = place.building_analyses_in_place
      if buildings_in_place.count >= 3
        @places_virtual_tour_ready += 1
        
        # Check if buildings have coordinates for physical tours
        buildings_with_coords = buildings_in_place.where.not(latitude: nil, longitude: nil)
        if buildings_with_coords.count >= 3
          @places_physical_tour_ready += 1
        end
      end
    end
    
    # User engagement metrics
    @users_with_buildings = User.joins(:building_analyses).distinct.count
    @avg_buildings_per_user = @users_with_buildings > 0 ? (@total_buildings.to_f / @users_with_buildings).round(1) : 0
    
    # Growth trends (last 7 days vs previous 7 days)
    seven_days_ago = 7.days.ago
    fourteen_days_ago = 14.days.ago
    
    @users_last_7_days = User.where('created_at >= ?', seven_days_ago).count
    @users_previous_7_days = User.where('created_at >= ? AND created_at < ?', fourteen_days_ago, seven_days_ago).count
    @user_growth_rate = @users_previous_7_days > 0 ? ((@users_last_7_days - @users_previous_7_days).to_f / @users_previous_7_days * 100).round(1) : 0
    
    @buildings_last_7_days = BuildingAnalysis.where('created_at >= ?', seven_days_ago).count
    @buildings_previous_7_days = BuildingAnalysis.where('created_at >= ? AND created_at < ?', fourteen_days_ago, seven_days_ago).count
    @building_growth_rate = @buildings_previous_7_days > 0 ? ((@buildings_last_7_days - @buildings_previous_7_days).to_f / @buildings_previous_7_days * 100).round(1) : 0

    # Time series data for charts
    generate_time_series_data
  end

  private

  def generate_time_series_data
    # Generate data for the last 30 days
    @chart_data = {}
    
    # User registrations over time
    @chart_data[:users] = []
    30.downto(0) do |days_ago|
      date = days_ago.days.ago.to_date
      count = User.where('DATE(created_at) = ?', date).count
      @chart_data[:users] << { date: date.strftime('%m/%d'), count: count }
    end
    
    # Building submissions over time
    @chart_data[:buildings] = []
    30.downto(0) do |days_ago|
      date = days_ago.days.ago.to_date
      count = BuildingAnalysis.where('DATE(created_at) = ?', date).count
      @chart_data[:buildings] << { date: date.strftime('%m/%d'), count: count }
    end
    
    # Active users over time (7-day rolling window)
    @chart_data[:active_users] = []
    30.downto(0) do |days_ago|
      date = days_ago.days.ago.to_date
      start_date = date - 7.days
      count = User.joins(:building_analyses)
                  .where('building_analyses.created_at >= ? AND building_analyses.created_at <= ?', start_date, date.end_of_day)
                  .distinct.count
      @chart_data[:active_users] << { date: date.strftime('%m/%d'), count: count }
    end
    
    # Style popularity over time
    @chart_data[:styles] = []
    style_counts = BuildingAnalysis.where(visible_in_library: true)
                                  .where('created_at >= ?', 30.days.ago)
                                  .pluck(:h3_contents)
                                  .compact
                                  .flat_map { |content| JSON.parse(content) rescue [] }
                                  .tally
                                  .sort_by { |_, count| -count }
                                  .first(10)
    
    @chart_data[:styles] = style_counts.map { |style, count| { style: style.gsub(/\s*\d+%$/, ''), count: count } }
  end
end
