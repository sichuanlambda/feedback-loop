class LeaderboardsController < ApplicationController
  def index
    @timeframe = params[:timeframe] || 'all-time'
    @category = params[:category] || 'level'
    
    # Get leaderboard data based on timeframe and category
    @leaderboard_data = get_leaderboard_data(@timeframe, @category)
    
    # Get current user's position if logged in
    @user_position = current_user ? get_user_position(current_user, @timeframe, @category) : nil
    
    # Get some summary stats
    @total_users = get_total_users_count
    @this_week_users = get_active_users_this_week
  end

  def weekly
    redirect_to leaderboards_path(timeframe: 'weekly', category: params[:category] || 'level')
  end

  def collection_map
    @style_collections = get_collection_map_data
    @top_collectors_by_style = get_top_collectors_by_style
  end

  private

  def get_leaderboard_data(timeframe, category)
    case timeframe
    when 'weekly'
      get_weekly_leaderboard(category)
    else # 'all-time'
      get_all_time_leaderboard(category)
    end
  end

  def get_weekly_leaderboard(category)
    # Get users who were active this week
    week_start = 1.week.ago.beginning_of_week
    
    case category
    when 'level'
      UserLevel.joins(:user)
              .where(users: { email: ['', nil] })  # Exclude Atlas admin
              .where.not(users: { email: 'atlas@architecturehelper.com' })
              .where('user_levels.last_activity_at >= ?', week_start)
              .includes(:user)
              .order(level: :desc, total_points: :desc)
              .limit(50)
              .map.with_index(1) do |user_level, rank|
        {
          rank: rank,
          user: user_level.user,
          level: user_level.level,
          total_points: user_level.total_points,
          buildings_analyzed: user_level.buildings_analyzed,
          this_week: true
        }
      end
    when 'buildings'
      # Users with building analyses from this week
      User.joins(:building_analyses)
          .where.not(email: 'atlas@architecturehelper.com')
          .where('building_analyses.created_at >= ?', week_start)
          .group('users.id')
          .order(Arel.sql('COUNT(building_analyses.id) DESC'))
          .limit(50)
          .includes(:user_level)
          .map.with_index(1) do |user, rank|
        weekly_count = user.building_analyses.where('created_at >= ?', week_start).count
        {
          rank: rank,
          user: user,
          level: user.user_level&.level || 1,
          total_points: user.user_level&.total_points || 0,
          buildings_analyzed: weekly_count,
          this_week: true
        }
      end
    when 'achievements'
      # Users with achievements earned this week
      User.joins(:user_achievements)
          .where.not(email: 'atlas@architecturehelper.com')
          .where('user_achievements.earned_at >= ?', week_start)
          .group('users.id')
          .order(Arel.sql('COUNT(user_achievements.id) DESC'))
          .limit(50)
          .includes(:user_level)
          .map.with_index(1) do |user, rank|
        weekly_achievements = user.user_achievements.where('earned_at >= ?', week_start).count
        {
          rank: rank,
          user: user,
          level: user.user_level&.level || 1,
          total_points: user.user_level&.total_points || 0,
          achievements_earned: weekly_achievements,
          this_week: true
        }
      end
    end
  end

  def get_all_time_leaderboard(category)
    case category
    when 'level'
      LevelCalculationService.get_leaderboard(type: :level, limit: 50)
    when 'buildings'
      LevelCalculationService.get_leaderboard(type: :buildings, limit: 50)
    when 'achievements'
      User.joins(:user_level)
          .where.not(email: 'atlas@architecturehelper.com')
          .includes(:user_level, :user_achievements)
          .order('user_levels.achievements_earned DESC, user_levels.total_points DESC')
          .limit(50)
          .map.with_index(1) do |user, rank|
        {
          rank: rank,
          user: user,
          level: user.user_level&.level || 1,
          total_points: user.user_level&.total_points || 0,
          achievements_earned: user.user_level&.achievements_earned || 0,
          buildings_analyzed: user.user_level&.buildings_analyzed || 0
        }
      end
    when 'points'
      LevelCalculationService.get_leaderboard(type: :points, limit: 50)
    end
  end

  def get_user_position(user, timeframe, category)
    return nil if user.email == 'atlas@architecturehelper.com'
    
    case timeframe
    when 'weekly'
      get_weekly_user_position(user, category)
    else
      LevelCalculationService.get_user_rank(user, type: category.to_sym)
    end
  end

  def get_weekly_user_position(user, category)
    week_start = 1.week.ago.beginning_of_week
    
    case category
    when 'level'
      user_level = user.user_level
      return nil unless user_level&.last_activity_at && user_level.last_activity_at >= week_start
      
      UserLevel.joins(:user)
              .where.not(users: { email: 'atlas@architecturehelper.com' })
              .where('user_levels.last_activity_at >= ?', week_start)
              .where(
                '(level > ?) OR (level = ? AND total_points > ?)',
                user_level.level,
                user_level.level,
                user_level.total_points
              )
              .count + 1
    when 'buildings'
      weekly_count = user.building_analyses.where('created_at >= ?', week_start).count
      return nil if weekly_count == 0
      
      User.joins(:building_analyses)
          .where.not(email: 'atlas@architecturehelper.com')
          .where('building_analyses.created_at >= ?', week_start)
          .group('users.id')
          .having('COUNT(building_analyses.id) > ?', weekly_count)
          .count
          .length + 1
    end
  end

  def get_total_users_count
    User.joins(:user_level).where.not(email: 'atlas@architecturehelper.com').count
  end

  def get_active_users_this_week
    week_start = 1.week.ago.beginning_of_week
    User.joins(:user_level)
        .where.not(email: 'atlas@architecturehelper.com')
        .where('user_levels.last_activity_at >= ?', week_start)
        .count
  end

  def get_collection_map_data
    # Get all style collections grouped by style
    UserStyleCollection.joins(:user)
                      .where.not(users: { email: 'atlas@architecturehelper.com' })
                      .group(:style_name)
                      .select('style_name, COUNT(*) as collector_count, SUM(building_count) as total_buildings')
                      .order(collector_count: :desc)
                      .limit(20)
  end

  def get_top_collectors_by_style
    # Get top 3 collectors for each popular style
    popular_styles = UserStyleCollection.joins(:user)
                                       .where.not(users: { email: 'atlas@architecturehelper.com' })
                                       .group(:style_name)
                                       .having('COUNT(*) > 1')
                                       .order('COUNT(*) DESC')
                                       .limit(10)
                                       .pluck(:style_name)

    collections = {}
    popular_styles.each do |style|
      collections[style] = UserStyleCollection.joins(:user)
                                             .where(style_name: style)
                                             .where.not(users: { email: 'atlas@architecturehelper.com' })
                                             .includes(:user)
                                             .order(building_count: :desc)
                                             .limit(3)
    end
    
    collections
  end
end