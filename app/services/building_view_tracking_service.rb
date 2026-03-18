class BuildingViewTrackingService
  def self.track_view(user, building_analysis)
    return unless user && building_analysis
    return if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    # Update or create style collections based on the building's styles
    update_style_collections(user, building_analysis)
    
    # Update user level stats
    update_user_level(user)
    
    # Check for new achievements
    AchievementCheckingService.check_achievements(user)
  end

  private

  def self.update_style_collections(user, building_analysis)
    return unless building_analysis.h3_contents.present?

    begin
      styles = JSON.parse(building_analysis.h3_contents)
      normalized_styles = StyleNormalizer.normalize_array(styles)
      
      normalized_styles.each do |style|
        collection = UserStyleCollection.find_or_create_by(
          user: user, 
          style_name: style
        ) do |new_collection|
          new_collection.building_count = 0
          new_collection.first_collected_at = Time.current
          new_collection.last_updated_at = Time.current
          new_collection.building_ids = []
        end
        
        collection.add_building(building_analysis)
      end
    rescue JSON::ParserError => e
      Rails.logger.warn "Failed to parse styles for building #{building_analysis.id}: #{e.message}"
    end
  end

  def self.update_user_level(user)
    user_level = UserLevel.find_or_create_for_user(user)
    user_level.update_stats!
  end
end