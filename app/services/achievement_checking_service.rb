class AchievementCheckingService
  def self.check_achievements(user, trigger = nil)
    return if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    new(user).check_all(trigger)
  end

  def initialize(user)
    @user = user
    @achievements_config = load_achievements_config
    @newly_earned = []
  end

  def check_all(trigger = nil)
    achievements_to_check = if trigger
      get_achievements_for_trigger(trigger)
    else
      @achievements_config['achievements'].keys
    end

    achievements_to_check.each do |achievement_key|
      check_single_achievement(achievement_key)
    end

    @newly_earned
  end

  private

  def load_achievements_config
    config_path = Rails.root.join('config', 'gamification', 'achievements.yml')
    YAML.load_file(config_path)
  end

  def get_achievements_for_trigger(trigger)
    checking_config = @achievements_config['checking']
    trigger_config = checking_config['triggers'].find { |t| t['event'] == trigger.to_s }
    return [] unless trigger_config

    categories = trigger_config['checks']
    @achievements_config['achievements'].select do |key, config|
      categories.include?(config['category'])
    end.keys
  end

  def check_single_achievement(achievement_key)
    achievement_config = @achievements_config['achievements'][achievement_key]
    return unless achievement_config

    # Skip if user already has this achievement
    return if @user.user_achievements.exists?(achievement_key: achievement_key)

    # Check if criteria are met
    if criteria_met?(achievement_config['criteria'])
      award_achievement(achievement_key, achievement_config)
    end
  end

  def criteria_met?(criteria)
    return false unless criteria

    # Check building analysis count
    if criteria['buildings_analyzed']
      return false unless @user.building_analyses.count >= criteria['buildings_analyzed']
    end

    # Check style collection count
    if criteria['styles_collected']
      return false unless @user.user_style_collections.count >= criteria['styles_collected']
    end

    # Check specific style collection requirements
    if criteria['style_collection']
      style = criteria['style_collection']['style']
      required_count = criteria['style_collection']['count']
      
      collection = @user.user_style_collections.find_by(style_name: style)
      return false unless collection && collection.building_count >= required_count
    end

    # Check location-based criteria
    if criteria['location_analysis']
      city = criteria['location_analysis']['city']
      required_count = criteria['location_analysis']['count']
      
      # Count buildings in specific city (simplified - would need geocoding in real app)
      city_count = count_buildings_in_city(city)
      return false unless city_count >= required_count
    end

    # Check diversity criteria
    if criteria['diverse_collections']
      min_styles = criteria['diverse_collections']['min_styles']
      min_per_style = criteria['diverse_collections']['min_per_style']
      
      qualified_collections = @user.user_style_collections
                                  .where('building_count >= ?', min_per_style)
                                  .count
      return false unless qualified_collections >= min_styles
    end

    # Check daily analysis criteria
    if criteria['daily_analysis']
      required_count = criteria['daily_analysis']
      today_count = @user.building_analyses
                        .where('created_at >= ?', Date.current.beginning_of_day)
                        .count
      return false unless today_count >= required_count
    end

    # Check weekend streak criteria
    if criteria['weekend_streak']
      required_streak = criteria['weekend_streak']
      current_streak = calculate_weekend_streak
      return false unless current_streak >= required_streak
    end

    # Check weekly first criteria
    if criteria['weekly_first']
      required_count = criteria['weekly_first']
      this_week_count = @user.building_analyses
                            .where('created_at >= ?', Date.current.beginning_of_week)
                            .count
      return false unless this_week_count >= required_count
      
      # Check if user was actually first (simplified logic)
      return false unless was_first_this_week?
    end

    true
  end

  def award_achievement(achievement_key, achievement_config)
    achievement = @user.user_achievements.create!(
      achievement_key: achievement_key,
      earned_at: Time.current,
      badge_count: achievement_config['badge_count'] || 1,
      metadata: {
        name: achievement_config['name'],
        description: achievement_config['description'],
        icon: achievement_config['icon'],
        category: achievement_config['category'],
        points: achievement_config['points']
      }.to_json
    )

    @newly_earned << achievement

    # Update user level after earning achievement
    LevelCalculationService.update_user_level(@user)

    Rails.logger.info "User #{@user.id} earned achievement: #{achievement_key}"
    
    achievement
  end

  def count_buildings_in_city(city)
    # Match buildings by address field containing city name
    @user.building_analyses
         .where('LOWER(COALESCE(address, \'\')) LIKE ?', "%#{city.downcase}%")
         .count
  rescue => e
    Rails.logger.warn("Achievement city check failed for #{city}: #{e.message}")
    0
  end

  def calculate_weekend_streak
    # Calculate consecutive weekends with activity
    current_date = Date.current
    streak = 0
    
    # Start from last weekend and work backwards
    weekend_start = current_date.beginning_of_week + 5.days # Saturday
    
    10.times do |i| # Check last 10 weekends max
      weekend_end = weekend_start + 1.day # Sunday
      check_start = weekend_start - (i * 7).days
      check_end = weekend_end - (i * 7).days
      
      weekend_activity = @user.building_analyses
                             .where(created_at: check_start..check_end)
                             .exists?
      
      if weekend_activity
        streak += 1
      else
        break
      end
    end
    
    streak
  end

  def was_first_this_week?
    # Simplified logic to check if user was among first to analyze buildings this week
    # In production, this would be more sophisticated
    week_start = Date.current.beginning_of_week
    total_analyses_this_week = BuildingAnalysis.where('created_at >= ?', week_start).count
    user_analyses_this_week = @user.building_analyses.where('created_at >= ?', week_start).count
    
    # User needs to have meaningful contribution to week's total
    total_analyses_this_week > 0 && (user_analyses_this_week.to_f / total_analyses_this_week) >= 0.1
  end

  # Class methods for batch checking and management
  def self.check_all_users_achievements(trigger = nil)
    User.where.not(email: 'atlas@architecturehelper.com').find_each do |user|
      check_achievements(user, trigger)
    end
  end

  def self.award_manual_achievement(user, achievement_key, reason = nil)
    return if user.email == 'atlas@architecturehelper.com'
    
    service = new(user)
    achievement_config = service.send(:load_achievements_config)['achievements'][achievement_key]
    
    return unless achievement_config
    return if user.user_achievements.exists?(achievement_key: achievement_key)

    service.send(:award_achievement, achievement_key, achievement_config)
  end

  def self.get_achievement_progress(user)
    return {} if user.email == 'atlas@architecturehelper.com'

    service = new(user)
    achievements_config = service.send(:load_achievements_config)
    
    progress = {}
    
    achievements_config['achievements'].each do |key, config|
      earned = user.user_achievements.exists?(achievement_key: key)
      
      progress[key] = {
        earned: earned,
        name: config['name'],
        description: config['description'],
        category: config['category'],
        icon: config['icon'],
        points: config['points'],
        progress_percent: earned ? 100 : service.send(:calculate_progress_percent, config['criteria'])
      }
    end
    
    progress
  end

  def calculate_progress_percent(criteria)
    return 0 unless criteria

    # Calculate progress towards achievement
    if criteria['buildings_analyzed']
      current = @user.building_analyses.count
      target = criteria['buildings_analyzed']
      return [(current.to_f / target * 100).round, 100].min
    end

    if criteria['styles_collected']
      current = @user.user_style_collections.count
      target = criteria['styles_collected']
      return [(current.to_f / target * 100).round, 100].min
    end

    if criteria['style_collection']
      style = criteria['style_collection']['style']
      target = criteria['style_collection']['count']
      collection = @user.user_style_collections.find_by(style_name: style)
      current = collection&.building_count || 0
      return [(current.to_f / target * 100).round, 100].min
    end

    # For complex criteria, return 0 or 100
    criteria_met?(criteria) ? 100 : 0
  end
end