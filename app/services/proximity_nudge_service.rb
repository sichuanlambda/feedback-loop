class ProximityNudgeService
  def self.get_nudges_for_building(user, building_analysis)
    return [] unless user && building_analysis
    return [] if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    new(user, building_analysis).generate_nudges
  end

  def initialize(user, building_analysis)
    @user = user
    @building = building_analysis
    @nudges = []
  end

  def generate_nudges
    check_style_collection_nudges
    check_nearby_achievement_nudges
    check_progress_nudges
    check_exploration_nudges
    
    @nudges.take(3) # Limit to 3 nudges to avoid clutter
  end

  private

  def check_style_collection_nudges
    return unless @building.h3_contents.present?

    styles = begin
      JSON.parse(@building.h3_contents)
    rescue JSON::ParserError
      []
    end

    styles.each do |style|
      normalized_style = StyleNormalizer.normalize(style)
      collection = @user.user_style_collections.find_by(style_name: normalized_style)
      
      if collection
        # User has this style collection - encourage expansion
        buildings_needed = next_milestone(collection.building_count) - collection.building_count
        if buildings_needed > 0 && buildings_needed <= 5
          @nudges << {
            type: 'collection_expansion',
            title: "#{normalized_style} Collection",
            message: "You have #{collection.building_count} #{normalized_style} buildings. Find #{buildings_needed} more to reach the next milestone!",
            icon: '🏛️',
            action_text: "Explore #{normalized_style}",
            action_url: style_buildings_path(style: normalized_style.parameterize)
          }
        end
      else
        # New style collection opportunity
        style_count = count_style_in_area(normalized_style)
        if style_count >= 3
          @nudges << {
            type: 'new_collection',
            title: "Start #{normalized_style} Collection",
            message: "There are #{style_count} #{normalized_style} buildings in this area. Start collecting!",
            icon: '✨',
            action_text: "Start Collection",
            action_url: style_buildings_path(style: normalized_style.parameterize)
          }
        end
      end
    end
  end

  def check_nearby_achievement_nudges
    # Check for location-based achievements
    if @building.latitude.present? && @building.longitude.present?
      city = extract_city_from_address(@building.address)
      
      if city.present?
        user_city_count = count_user_buildings_in_city(city)
        total_city_count = count_total_buildings_in_city(city)
        
        # City explorer nudges
        if user_city_count == 1 && total_city_count >= 5
          @nudges << {
            type: 'city_exploration',
            title: "Explore #{city}",
            message: "You've analyzed 1 building in #{city}. There are #{total_city_count - 1} more to discover!",
            icon: '🗺️',
            action_text: "Explore #{city}",
            action_url: by_location_path(city: city.parameterize)
          }
        elsif user_city_count >= 3 && user_city_count < 10
          milestone_needed = [5, 10, 20].find { |m| m > user_city_count } || 25
          needed = milestone_needed - user_city_count
          @nudges << {
            type: 'city_milestone',
            title: "#{city} Expert Progress",
            message: "#{user_city_count}/#{milestone_needed} buildings analyzed in #{city}. #{needed} more to go!",
            icon: '🎯',
            action_text: "Continue exploring",
            action_url: by_location_path(city: city.parameterize)
          }
        end
      end
    end
  end

  def check_progress_nudges
    # Daily streak nudges
    today_count = @user.building_analyses.where('created_at >= ?', Date.current.beginning_of_day).count
    
    if today_count == 1
      @nudges << {
        type: 'daily_streak',
        title: 'Daily Streak Started!',
        message: 'You\'ve analyzed your first building today. Keep the momentum going!',
        icon: '🔥',
        action_text: 'Find another',
        action_url: building_library_path
      }
    elsif today_count >= 3 && today_count < 5
      @nudges << {
        type: 'daily_milestone',
        title: 'On a Roll!',
        message: "#{today_count} buildings analyzed today. Reach 5 for a special achievement!",
        icon: '⚡',
        action_text: 'Keep going',
        action_url: building_library_path
      }
    end

    # Weekly first encouragement
    week_start = Date.current.beginning_of_week
    this_week_count = @user.building_analyses.where('created_at >= ?', week_start).count
    
    if this_week_count == 1
      total_week_count = BuildingAnalysis.where('created_at >= ?', week_start).count
      if total_week_count <= 50 # Early in the week
        @nudges << {
          type: 'weekly_first',
          title: 'Early Bird!',
          message: 'You\'re among the first to analyze buildings this week. Keep leading!',
          icon: '🐦',
          action_text: 'Stay ahead',
          action_url: building_library_path
        }
      end
    end
  end

  def check_exploration_nudges
    # Encourage style diversity
    user_styles = @user.user_style_collections.count
    
    if user_styles >= 2 && user_styles < 5
      @nudges << {
        type: 'style_diversity',
        title: 'Style Explorer',
        message: "You've collected #{user_styles} different architectural styles. Discover more for variety bonuses!",
        icon: '🎨',
        action_text: 'Explore styles',
        action_url: styles_index_path
      }
    end

    # Encourage sharing/community
    visible_count = @user.building_analyses.where(visible_in_library: true).count
    if visible_count >= 3 && visible_count < 10
      profile_path = user_signed_in? ? profile_path(username: @user.handle || @user.id) : nil
      if profile_path
        @nudges << {
          type: 'sharing_encouragement',
          title: 'Share Your Discoveries',
          message: "You've shared #{visible_count} buildings with the community. Your profile is looking great!",
          icon: '🤝',
          action_text: 'View profile',
          action_url: profile_path
        }
      end
    end
  end

  # Helper methods
  def next_milestone(current_count)
    milestones = [3, 5, 10, 15, 25, 50, 100]
    milestones.find { |m| m > current_count } || (current_count + 25)
  end

  def count_style_in_area(style)
    # Count buildings with this style in a 10km radius (simplified)
    if @building.latitude.present? && @building.longitude.present?
      BuildingAnalysis.where(visible_in_library: true)
        .where("LOWER(h3_contents) LIKE ?", "%#{style.downcase}%")
        .where("latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?",
               @building.latitude - 0.1, @building.latitude + 0.1,
               @building.longitude - 0.1, @building.longitude + 0.1)
        .count
    else
      # Fallback to city-based counting
      city = extract_city_from_address(@building.address)
      return 0 unless city
      
      BuildingAnalysis.joins("LEFT JOIN building_analyses ba2 ON ba2.address LIKE '%#{city}%'")
        .where(visible_in_library: true)
        .where("LOWER(building_analyses.h3_contents) LIKE ?", "%#{style.downcase}%")
        .count
    end
  end

  def count_user_buildings_in_city(city)
    @user.building_analyses
         .where("LOWER(address) LIKE ?", "%#{city.downcase}%")
         .count
  end

  def count_total_buildings_in_city(city)
    BuildingAnalysis.where(visible_in_library: true)
                   .where("LOWER(address) LIKE ?", "%#{city.downcase}%")
                   .count
  end

  def extract_city_from_address(address)
    return nil unless address.present?
    
    # Extract city from address (simplified - assumes "Street, City, State" format)
    parts = address.split(',')
    return nil if parts.length < 2
    
    parts[-2].strip # Second to last part is usually the city
  end

  # Route helpers - these would need to be defined in routes
  def style_buildings_path(options = {})
    "/styles/#{options[:style]}" # Simplified path
  end

  def by_location_path(options = {})
    "/locations/#{options[:city]}" # Simplified path
  end

  def building_library_path
    "/building_library"
  end

  def styles_index_path
    "/styles"
  end

  def profile_path(options = {})
    "/profile/#{options[:username]}"
  end
end