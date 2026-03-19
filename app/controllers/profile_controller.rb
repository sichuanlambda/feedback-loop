class ProfileController < ApplicationController
  before_action :authenticate_user!, only: []
  before_action :set_user

  def show
    @user_level = UserLevel.find_or_create_for_user(@user)
    @style_collections = load_style_collections
    @achievements = load_achievements
    @recent_analyses = load_recent_analyses
    @level_progress = calculate_level_progress
    @achievement_stats = calculate_achievement_stats
  end

  def style_collection
    @style_name = params[:style_name]
    @collection = @user.user_style_collections.find_by(style_name: @style_name)
    
    if @collection
      @buildings = @collection.buildings.limit(50)
      @collection_stats = calculate_collection_stats(@collection)
    else
      redirect_to profile_path, alert: "Style collection not found."
    end
  end

  def achievements
    @achievement_progress = AchievementCheckingService.get_achievement_progress(@user)
    @categories = load_achievement_categories
    @achievements_by_category = group_achievements_by_category(@achievement_progress)
  end

  def public_profile
    # Public profile view for sharing
    @user = User.find_by(handle: params[:username]) || User.find_by(id: params[:username])
    
    unless @user
      redirect_to root_path, alert: "Profile not found."
      return
    end

    # Skip Atlas admin from public profiles
    if @user.email == 'atlas@architecturehelper.com'
      redirect_to root_path, alert: "Profile not available."
      return
    end

    @user_level = UserLevel.find_or_create_for_user(@user)
    @style_collections = load_style_collections
    @achievements = load_achievements
    @recent_analyses = load_recent_analyses.limit(6) # Limit for sharing view
    @level_progress = calculate_level_progress
    @achievement_stats = calculate_achievement_stats

    # Generate share metadata
    @share_title = "#{@user.public_name || @user.handle}'s Architecture Profile"
    @share_description = generate_share_description
    @share_image = generate_profile_share_image

    # Set meta tags for social sharing
    set_profile_meta_tags

    render 'show'
  end

  def leaderboard_position
    @level_rank = LevelCalculationService.get_user_rank(@user, type: :level)
    @points_rank = LevelCalculationService.get_user_rank(@user, type: :points)
    @buildings_rank = LevelCalculationService.get_user_rank(@user, type: :buildings)
    
    @level_leaderboard = LevelCalculationService.get_leaderboard(type: :level, limit: 10)
    @user_level = UserLevel.find_or_create_for_user(@user)
  end

  private

  def set_user
    if params[:user_id]
      @user = User.find_by(id: params[:user_id]) || User.find_by(handle: params[:user_id])
    else
      @user = current_user
    end
    
    unless @user
      redirect_to root_path, alert: "User not found."
      return
    end
    
    # Redirect Atlas admin to prevent profile access
    if @user.email == 'atlas@architecturehelper.com'
      redirect_to root_path, alert: "Profile not accessible."
      return
    end
  end

  def load_style_collections
    @user.user_style_collections
         .order(building_count: :desc)
         .limit(20)
         .map do |collection|
      {
        collection: collection,
        sample_buildings: collection.buildings.limit(3),
        completion_level: StyleCollectionService.send(:calculate_completion_level, collection.building_count),
        style_leaderboard_position: get_style_leaderboard_position(collection.style_name)
      }
    end
  end

  def load_achievements
    @user.user_achievements
         .order(earned_at: :desc)
         .limit(12)
         .map do |achievement|
      metadata = JSON.parse(achievement.metadata || '{}')
      {
        achievement: achievement,
        name: metadata['name'],
        description: metadata['description'],
        icon: metadata['icon'],
        category: metadata['category'],
        earned_at: achievement.earned_at
      }
    end
  end

  def load_recent_analyses
    @user.building_analyses
         .order(created_at: :desc)
         .limit(6)
  end

  def calculate_level_progress
    next_level = @user_level.level + 1
    next_threshold = UserLevel::LEVEL_THRESHOLDS[next_level]
    
    if next_threshold
      {
        current_points: @user_level.total_points,
        points_to_next: @user_level.points_to_next_level,
        progress_percent: @user_level.level_progress_percentage,
        next_level: next_level,
        current_level: @user_level.level
      }
    else
      {
        current_points: @user_level.total_points,
        points_to_next: nil,
        progress_percent: 100,
        next_level: nil,
        current_level: @user_level.level,
        max_level_reached: true
      }
    end
  end

  def calculate_achievement_stats
    total_achievements = YAML.load_file(Rails.root.join('config', 'gamification', 'achievements.yml'))['achievements'].count
    earned_achievements = @user.user_achievements.count
    
    {
      earned: earned_achievements,
      total: total_achievements,
      completion_percent: (earned_achievements.to_f / total_achievements * 100).round(1)
    }
  end

  def get_style_leaderboard_position(style_name)
    leaderboard = StyleCollectionService.get_style_leaderboard(style_name, limit: 100)
    position = leaderboard.find_index { |entry| entry[:user].id == @user.id }
    position ? position + 1 : nil
  end

  def load_achievement_categories
    config = YAML.load_file(Rails.root.join('config', 'gamification', 'achievements.yml'))
    config['badge_display']['categories']
  end

  def group_achievements_by_category(achievement_progress)
    grouped = {}
    
    achievement_progress.each do |key, achievement|
      category = achievement[:category]
      grouped[category] ||= []
      grouped[category] << achievement.merge(key: key)
    end
    
    grouped
  end

  def calculate_collection_stats(collection)
    all_collections = UserStyleCollection.where(style_name: collection.style_name)
    user_rank = all_collections.where('building_count > ?', collection.building_count).count + 1
    total_collectors = all_collections.count
    
    {
      user_rank: user_rank,
      total_collectors: total_collectors,
      average_collection_size: all_collections.average(:building_count)&.round(1) || 0,
      top_collection_size: all_collections.maximum(:building_count) || 0
    }
  end

  def generate_share_description
    stats = []
    stats << "Level #{@user_level.level}" if @user_level&.level
    stats << "#{@achievements.count} achievements" if @achievements&.any?
    stats << "#{@style_collections.count} style collections" if @style_collections&.any?
    stats << "#{@user.building_analyses.count} buildings analyzed"

    description = "#{@user.public_name || @user.handle} is an architecture enthusiast on Architecture Helper"
    description += " - #{stats.join(', ')}" if stats.any?
    description += ". Discover their architectural journey and style collections!"

    description
  end

  def generate_profile_share_image
    # Use the user's most recent building analysis image, or a default profile image
    recent_with_image = @user.building_analyses
                            .where.not(image_url: [nil, ''])
                            .order(created_at: :desc)
                            .first

    recent_with_image&.image_url || '/assets/default-profile-share.jpg'
  end

  def set_profile_meta_tags
    # Set meta tags for social media sharing
    @meta_title = @share_title
    @meta_description = @share_description
    @meta_image = @share_image
    @canonical_url = public_profile_url(username: @user.handle || @user.id)
  end
end