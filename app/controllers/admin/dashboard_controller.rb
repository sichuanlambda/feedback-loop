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
    # Get timeframe from params, default to 30 days
    @timeframe = params[:timeframe] || '30d'
    @view_type = params[:view_type] || 'daily'
    
    # Validate view_type
    unless ['daily', 'weekly', 'monthly'].include?(@view_type)
      @view_type = 'daily'
    end
    
    # Set date ranges based on timeframe
    case @timeframe
    when '7d'
      @start_date = 7.days.ago
      @period_label = 'Last 7 Days'
    when '30d'
      @start_date = 30.days.ago
      @period_label = 'Last 30 Days'
    when '90d'
      @start_date = 90.days.ago
      @period_label = 'Last 90 Days'
    when '1y'
      @start_date = 1.year.ago
      @period_label = 'Last Year'
    when 'all'
      @start_date = 10.years.ago # Effectively all time
      @period_label = 'All Time'
    else
      @start_date = 30.days.ago
      @period_label = 'Last 30 Days'
    end
    
    # Basic statistics
    @total_buildings = BuildingAnalysis.count
    @visible_buildings = BuildingAnalysis.where(visible_in_library: true).count
    @hidden_buildings = BuildingAnalysis.where(visible_in_library: false).count
    @total_users = User.count
    @total_arch_images = ArchImageGen.count
    
    # Time-based statistics for selected period
    @new_users_period = User.where('created_at >= ?', @start_date).count
    @new_users_7_days = User.where('created_at >= ?', 7.days.ago).count
    @new_users_today = User.where('created_at >= ?', Date.current.beginning_of_day).count
    
    # Active users (users who have submitted buildings in selected period)
    @active_users_period = User.joins(:building_analyses)
                               .where('building_analyses.created_at >= ?', @start_date)
                               .distinct.count
    
    # Buildings submitted in selected period
    @buildings_period = BuildingAnalysis.where('created_at >= ?', @start_date).count
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
    
    # Growth trends (comparing current period with previous period of same length)
    previous_start = @start_date - (@start_date - 30.days.ago).abs
    
    @users_current_period = User.where('created_at >= ?', @start_date).count
    @users_previous_period = User.where('created_at >= ? AND created_at < ?', previous_start, @start_date).count
    @user_growth_rate = @users_previous_period > 0 ? ((@users_current_period - @users_previous_period).to_f / @users_previous_period * 100).round(1) : 0
    
    @buildings_current_period = BuildingAnalysis.where('created_at >= ?', @start_date).count
    @buildings_previous_period = BuildingAnalysis.where('created_at >= ? AND created_at < ?', previous_start, @start_date).count
    @building_growth_rate = @buildings_previous_period > 0 ? ((@buildings_current_period - @buildings_previous_period).to_f / @buildings_previous_period * 100).round(1) : 0

    # Weekly and aggregate statistics
    generate_weekly_aggregate_stats
    
    # Time series data for charts
    generate_time_series_data
  end

  private

  def generate_weekly_aggregate_stats
    # Weekly statistics for the selected period
    @weekly_stats = {}
    
    # Calculate weeks in the period
    weeks_in_period = ((Date.current - @start_date.to_date) / 7.0).ceil
    
    @weekly_stats[:users] = []
    @weekly_stats[:buildings] = []
    @weekly_stats[:active_users] = []
    
    weeks_in_period.times do |week|
      week_start = @start_date + (week * 7).days
      week_end = [week_start + 7.days, Date.current].min
      
      # Users per week
      users_count = User.where('created_at >= ? AND created_at < ?', week_start, week_end).count
      @weekly_stats[:users] << { week: week + 1, count: users_count, period: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}" }
      
      # Buildings per week
      buildings_count = BuildingAnalysis.where('created_at >= ? AND created_at < ?', week_start, week_end).count
      @weekly_stats[:buildings] << { week: week + 1, count: buildings_count, period: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}" }
      
      # Active users per week (rolling 7-day window)
      active_users_count = User.joins(:building_analyses)
                               .where('building_analyses.created_at >= ? AND building_analyses.created_at < ?', week_start, week_end)
                               .distinct.count
      @weekly_stats[:active_users] << { week: week + 1, count: active_users_count, period: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}" }
    end
    
    # Aggregate statistics
    places_with_buildings_count = 0
    Place.find_each do |place|
      if place.building_analyses_in_place.count > 0
        places_with_buildings_count += 1
      end
    end
    
    @aggregate_stats = {
      total_users_all_time: User.count,
      total_buildings_all_time: BuildingAnalysis.count,
      avg_users_per_week: @weekly_stats[:users].sum { |w| w[:count] } / weeks_in_period.to_f,
      avg_buildings_per_week: @weekly_stats[:buildings].sum { |w| w[:count] } / weeks_in_period.to_f,
      peak_week_users: @weekly_stats[:users].max_by { |w| w[:count] },
      peak_week_buildings: @weekly_stats[:buildings].max_by { |w| w[:count] },
      total_places_with_buildings: places_with_buildings_count,
      avg_buildings_per_place: places_with_buildings_count > 0 ? 
        (BuildingAnalysis.count.to_f / places_with_buildings_count).round(1) : 0
    }
  end

  def generate_time_series_data
    # Generate data for the selected timeframe
    @chart_data = {}
    
    # Determine number of data points based on timeframe and view type
    case @timeframe
    when '7d'
      data_points = case @view_type
                   when 'daily' then 7
                   when 'weekly' then 1
                   when 'monthly' then 1
                   else 7
                   end
      date_format = '%m/%d'
    when '30d'
      data_points = case @view_type
                   when 'daily' then 30
                   when 'weekly' then 5
                   when 'monthly' then 1
                   else 30
                   end
      date_format = '%m/%d'
    when '90d'
      data_points = case @view_type
                   when 'daily' then 90
                   when 'weekly' then 13
                   when 'monthly' then 3
                   else 90
                   end
      date_format = '%m/%d'
    when '1y'
      data_points = case @view_type
                   when 'daily' then 365
                   when 'weekly' then 52
                   when 'monthly' then 12
                   else 365
                   end
      date_format = '%m/%d'
    when 'all'
      data_points = case @view_type
                   when 'daily' then 365
                   when 'weekly' then 100
                   when 'monthly' then 24
                   else 365
                   end
      date_format = '%m/%d'
    else
      data_points = 30
      date_format = '%m/%d'
    end
    
    # User registrations over time
    @chart_data[:users] = []
    case @view_type
    when 'weekly'
      # Weekly data
      data_points.times do |i|
        week_start = @start_date + (i * 7).days
        week_end = [week_start + 7.days, Date.current].min
        count = User.where('created_at >= ? AND created_at < ?', week_start, week_end).count
        @chart_data[:users] << { date: "Week #{i + 1}", count: count, period: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}" }
      end
    when 'monthly'
      # Monthly data
      data_points.times do |i|
        month_start = @start_date + (i * 30).days
        month_end = [month_start + 30.days, Date.current].min
        count = User.where('created_at >= ? AND created_at < ?', month_start, month_end).count
        @chart_data[:users] << { date: "Month #{i + 1}", count: count, period: "#{month_start.strftime('%m/%Y')} - #{month_end.strftime('%m/%Y')}" }
      end
    else
      # Daily data
      data_points.downto(0) do |days_ago|
        date = days_ago.days.ago.to_date
        count = User.where('DATE(created_at) = ?', date).count
        @chart_data[:users] << { date: date.strftime(date_format), count: count }
      end
    end
    
    # Building submissions over time
    @chart_data[:buildings] = []
    case @view_type
    when 'weekly'
      # Weekly data
      data_points.times do |i|
        week_start = @start_date + (i * 7).days
        week_end = [week_start + 7.days, Date.current].min
        count = BuildingAnalysis.where('created_at >= ? AND created_at < ?', week_start, week_end).count
        @chart_data[:buildings] << { date: "Week #{i + 1}", count: count, period: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}" }
      end
    when 'monthly'
      # Monthly data
      data_points.times do |i|
        month_start = @start_date + (i * 30).days
        month_end = [month_start + 30.days, Date.current].min
        count = BuildingAnalysis.where('created_at >= ? AND created_at < ?', month_start, month_end).count
        @chart_data[:buildings] << { date: "Month #{i + 1}", count: count, period: "#{month_start.strftime('%m/%Y')} - #{month_end.strftime('%m/%Y')}" }
      end
    else
      # Daily data
      data_points.downto(0) do |days_ago|
        date = days_ago.days.ago.to_date
        count = BuildingAnalysis.where('DATE(created_at) = ?', date).count
        @chart_data[:buildings] << { date: date.strftime(date_format), count: count }
      end
    end
    
    # Active users over time (7-day rolling window)
    @chart_data[:active_users] = []
    case @view_type
    when 'weekly'
      # Weekly data
      data_points.times do |i|
        week_start = @start_date + (i * 7).days
        week_end = [week_start + 7.days, Date.current].min
        count = User.joins(:building_analyses)
                    .where('building_analyses.created_at >= ? AND building_analyses.created_at < ?', week_start, week_end)
                    .distinct.count
        @chart_data[:active_users] << { date: "Week #{i + 1}", count: count, period: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}" }
      end
    when 'monthly'
      # Monthly data
      data_points.times do |i|
        month_start = @start_date + (i * 30).days
        month_end = [month_start + 30.days, Date.current].min
        count = User.joins(:building_analyses)
                    .where('building_analyses.created_at >= ? AND building_analyses.created_at < ?', month_start, month_end)
                    .distinct.count
        @chart_data[:active_users] << { date: "Month #{i + 1}", count: count, period: "#{month_start.strftime('%m/%Y')} - #{month_end.strftime('%m/%Y')}" }
      end
    else
      # Daily data
      data_points.downto(0) do |days_ago|
        date = days_ago.days.ago.to_date
        start_date = date - 7.days
        count = User.joins(:building_analyses)
                    .where('building_analyses.created_at >= ? AND building_analyses.created_at <= ?', start_date, date.end_of_day)
                    .distinct.count
        @chart_data[:active_users] << { date: date.strftime(date_format), count: count }
      end
    end
    
    # Style popularity over time
    @chart_data[:styles] = []
    style_counts = BuildingAnalysis.where(visible_in_library: true)
                                  .where('created_at >= ?', @start_date)
                                  .pluck(:h3_contents)
                                  .compact
                                  .flat_map { |content| JSON.parse(content) rescue [] }
                                  .tally
                                  .sort_by { |_, count| -count }
                                  .first(10)
    
    @chart_data[:styles] = style_counts.map { |style, count| { style: style.gsub(/\s*\d+%$/, ''), count: count } }
  end
end
