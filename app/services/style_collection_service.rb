class StyleCollectionService
  def self.update_collections_for_building(user, building_analysis)
    return unless user && building_analysis
    return if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    styles = extract_styles_from_building(building_analysis)
    
    styles.each do |style|
      update_or_create_collection(user, style, building_analysis)
    end
    
    # Clean up collections that no longer have this building
    remove_building_from_other_collections(user, building_analysis, styles)
  end

  def self.get_user_style_grid(user)
    collections = user.user_style_collections
                     .includes(:user)
                     .by_building_count
                     .limit(50) # Limit for performance

    collections.map do |collection|
      {
        style_name: collection.style_name,
        building_count: collection.building_count,
        first_collected_at: collection.first_collected_at,
        sample_buildings: collection.buildings.limit(3).pluck(:name, :image_url),
        completion_level: calculate_completion_level(collection.building_count)
      }
    end
  end

  def self.get_style_leaderboard(style_name, limit: 10)
    UserStyleCollection.includes(:user)
                      .where(style_name: style_name)
                      .where.not(users: { email: 'atlas@architecturehelper.com' })
                      .by_building_count
                      .limit(limit)
                      .map do |collection|
      {
        user: collection.user,
        building_count: collection.building_count,
        first_collected_at: collection.first_collected_at
      }
    end
  end

  def self.calculate_style_diversity_score(user)
    collections = user.user_style_collections
    return 0 if collections.empty?

    # Score based on number of different styles and buildings per style
    style_count = collections.count
    avg_buildings_per_style = collections.average(:building_count) || 0
    
    # Bonus for having many styles with decent representation
    diversity_bonus = style_count > 10 ? 1.5 : 1.0
    
    (style_count * avg_buildings_per_style * diversity_bonus).round
  end

  private

  def self.extract_styles_from_building(building_analysis)
    return [] unless building_analysis.h3_contents.present?

    begin
      styles = JSON.parse(building_analysis.h3_contents)
      StyleNormalizer.normalize_array(styles)
    rescue JSON::ParserError
      []
    end
  end

  def self.update_or_create_collection(user, style, building_analysis)
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

  def self.remove_building_from_other_collections(user, building_analysis, current_styles)
    user.user_style_collections
        .where.not(style_name: current_styles)
        .each do |collection|
      collection.remove_building(building_analysis)
      
      # Remove empty collections
      if collection.building_count == 0
        collection.destroy
      end
    end
  end

  def self.calculate_completion_level(building_count)
    case building_count
    when 0...5
      'beginner'
    when 5...15
      'intermediate'
    when 15...30
      'advanced'
    when 30...50
      'expert'
    else
      'master'
    end
  end
end