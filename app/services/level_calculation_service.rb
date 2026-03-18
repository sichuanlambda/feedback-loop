class LevelCalculationService
  def self.update_user_level(user)
    return if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    user_level = UserLevel.find_or_create_for_user(user)
    old_level = user_level.level
    
    # Calculate points from all sources
    total_points = calculate_total_points(user)
    
    # Update all stats
    user_level.update!(
      total_points: total_points,
      buildings_analyzed: user.building_analyses.count,
      styles_collected: user.user_style_collections.count,
      achievements_earned: user.user_achievements.count,
      level: user_level.calculate_level_from_points,
      last_activity_at: Time.current,
      level_reached_at: user_level.level > old_level ? Time.current : user_level.level_reached_at
    )

    # Return level change info for potential notifications
    {
      leveled_up: user_level.level > old_level,
      old_level: old_level,
      new_level: user_level.level,
      total_points: total_points
    }
  end

  def self.calculate_total_points(user)
    contribution_points = user.building_contributions.sum(:points_awarded)
    achievement_points = calculate_achievement_points(user)
    style_points = calculate_style_collection_points(user)
    
    contribution_points + achievement_points + style_points
  end

  def self.get_leaderboard(type: :level, limit: 50)
    case type
    when :level
      UserLevel.for_leaderboard
              .includes(:user)
              .limit(limit)
              .map.with_index(1) do |user_level, rank|
        {
          rank: rank,
          user: user_level.user,
          level: user_level.level,
          total_points: user_level.total_points,
          buildings_analyzed: user_level.buildings_analyzed
        }
      end
    when :points
      UserLevel.for_leaderboard
              .includes(:user)
              .by_points
              .limit(limit)
              .map.with_index(1) do |user_level, rank|
        {
          rank: rank,
          user: user_level.user,
          level: user_level.level,
          total_points: user_level.total_points,
          buildings_analyzed: user_level.buildings_analyzed
        }
      end
    when :buildings
      User.joins(:user_level)
          .where.not(email: 'atlas@architecturehelper.com')
          .includes(:building_analyses, :user_level)
          .order(Arel.sql('(SELECT COUNT(*) FROM building_analyses WHERE user_id = users.id) DESC'))
          .limit(limit)
          .map.with_index(1) do |user, rank|
        {
          rank: rank,
          user: user,
          level: user.user_level&.level || 1,
          total_points: user.user_level&.total_points || 0,
          buildings_analyzed: user.building_analyses.count
        }
      end
    end
  end

  def self.get_user_rank(user, type: :level)
    return nil if user.email == 'atlas@architecturehelper.com'

    case type
    when :level
      user_level = user.user_level
      return nil unless user_level

      UserLevel.joins(:user)
              .where.not(users: { email: 'atlas@architecturehelper.com' })
              .where(
                '(level > ?) OR (level = ? AND total_points > ?)',
                user_level.level,
                user_level.level,
                user_level.total_points
              )
              .count + 1
    when :points
      user_level = user.user_level
      return nil unless user_level

      UserLevel.joins(:user)
              .where.not(users: { email: 'atlas@architecturehelper.com' })
              .where('total_points > ?', user_level.total_points)
              .count + 1
    when :buildings
      building_count = user.building_analyses.count
      User.joins(:building_analyses)
          .where.not(email: 'atlas@architecturehelper.com')
          .group('users.id')
          .having('COUNT(building_analyses.id) > ?', building_count)
          .count
          .length + 1
    end
  end

  private

  def self.calculate_achievement_points(user)
    # Different achievement types have different point values
    achievement_points = {
      'explorer_bronze' => 25,
      'explorer_silver' => 75,
      'explorer_gold' => 200,
      'collector_bronze' => 50,
      'collector_silver' => 150,
      'collector_gold' => 400,
      'style_master_art_deco' => 100,
      'style_master_modern' => 100,
      'style_master_victorian' => 100,
      'city_expert_nyc' => 150,
      'city_expert_chicago' => 150,
      'city_expert_sf' => 150,
      'first_building' => 10,
      'first_style_collection' => 15,
      'ten_buildings' => 30,
      'hundred_buildings' => 300,
      'diversity_champion' => 250,
      'speed_analyzer' => 50
    }

    user.user_achievements.sum do |achievement|
      (achievement_points[achievement.achievement_key] || 10) * achievement.badge_count
    end
  end

  def self.calculate_style_collection_points(user)
    # Points for style diversity and collection depth
    collections = user.user_style_collections
    return 0 if collections.empty?

    # 1 point per building in collections
    building_points = collections.sum(:building_count)
    
    # Bonus for diversity (5 points per unique style)
    diversity_points = collections.count * 5
    
    # Bonus for deep collections (extra points for 10+, 25+, 50+ buildings in a style)
    depth_bonus = collections.sum do |collection|
      case collection.building_count
      when 10...25
        10
      when 25...50
        25
      when 50..Float::INFINITY
        50
      else
        0
      end
    end

    building_points + diversity_points + depth_bonus
  end
end