class AutoPlaceGenerator
  def self.generate_places_from_buildings(min_buildings = 3)
    Rails.logger.info "Starting automatic place generation from building analyses (min: #{min_buildings} buildings)..."
    
    # First, populate city field from addresses if needed
    populate_city_from_address
    
    # Group buildings by city and count them
    city_building_counts = BuildingAnalysis.where(visible_in_library: true)
                                          .where.not(city: [nil, '', 'N/A'])
                                          .group(:city)
                                          .count
    
    # Filter cities with minimum buildings
    cities_with_enough_buildings = city_building_counts.select { |city, count| count >= min_buildings }
    
    Rails.logger.info "Found #{cities_with_enough_buildings.count} cities with #{min_buildings}+ buildings"
    
    created_places = []
    
    cities_with_enough_buildings.each do |city_name, building_count|
      # Skip if place already exists for this city
      existing_place = Place.find_by(name: city_name)
      next if existing_place.present?
      
      # Get sample building to extract coordinates
      sample_building = BuildingAnalysis.where(city: city_name, visible_in_library: true).first
      next unless sample_building&.latitude && sample_building&.longitude
      
      # Create place
      place = Place.new(
        name: city_name,
        latitude: sample_building.latitude,
        longitude: sample_building.longitude,
        zoom_level: 12,
        description: "Explore the architecture of #{city_name}. Discover #{building_count} analyzed buildings and their unique architectural styles.",
        published: true,
        featured: false
      )
      
      if place.save
        created_places << place
        Rails.logger.info "Created place: #{city_name} with #{building_count} buildings"
        
        # Queue content generation
        GeneratePlaceContentJob.perform_later(place.id)
      else
        Rails.logger.error "Failed to create place for #{city_name}: #{place.errors.full_messages}"
      end
    end
    
    Rails.logger.info "Auto place generation complete. Created #{created_places.count} new places."
    created_places
  end
  
  def self.populate_city_from_address
    Rails.logger.info "Populating city field from addresses..."
    
    updated_count = 0
    BuildingAnalysis.where(city: [nil, '', 'N/A']).where.not(address: [nil, '']).find_each do |building|
      city = extract_city_from_address(building.address)
      if city.present?
        building.update(city: city)
        updated_count += 1
      end
    end
    
    Rails.logger.info "Updated #{updated_count} buildings with city information."
  end
  
  def self.extract_city_from_address(address)
    return nil if address.blank?
    
    # Common patterns for extracting city from address
    patterns = [
      /,\s*([^,]+),\s*[A-Z]{2}\s*\d{5}/,  # "City, ST 12345"
      /,\s*([^,]+),\s*[A-Z]{2}$/,          # "City, ST"
      /,\s*([^,]+),\s*United States/,      # "City, United States"
      /,\s*([^,]+)$/                       # "City" at end
    ]
    
    patterns.each do |pattern|
      match = address.match(pattern)
      if match
        city = match[1].strip
        # Clean up common issues
        city = city.gsub(/\s+/, ' ').strip
        return city unless city.blank?
      end
    end
    
    nil
  end
  
  def self.consolidate_city_names
    Rails.logger.info "Consolidating similar city names..."
    
    # Define city name mappings (e.g., "Denver CO" -> "Denver")
    city_mappings = {
      "Denver CO" => "Denver",
      "Denver, CO" => "Denver",
      "Kansas City, MO" => "Kansas City",
      "New York, NY" => "New York"
    }
    
    updated_count = 0
    city_mappings.each do |old_name, new_name|
      buildings = BuildingAnalysis.where(city: old_name)
      if buildings.any?
        buildings.update_all(city: new_name)
        updated_count += buildings.count
        Rails.logger.info "Updated #{buildings.count} buildings from '#{old_name}' to '#{new_name}'"
      end
    end
    
    Rails.logger.info "Consolidated #{updated_count} buildings with updated city names."
  end
  
  def self.update_existing_places
    Rails.logger.info "Updating existing places with current building counts..."
    
    Place.find_each do |place|
      # Count buildings in this place's area
      building_count = place.building_analyses_in_place.count
      
      # Update description with current count
      if building_count > 0
        place.update(
          description: "Explore the architecture of #{place.name}. Discover #{building_count} analyzed buildings and their unique architectural styles."
        )
      end
    end
    
    Rails.logger.info "Place updates complete."
  end
  
  def self.cleanup_orphaned_places
    Rails.logger.info "Cleaning up places with no buildings..."
    
    orphaned_places = Place.joins("LEFT JOIN building_analyses ON building_analyses.latitude BETWEEN places.latitude - 0.1 AND places.latitude + 0.1 AND building_analyses.longitude BETWEEN places.longitude - 0.1 AND places.longitude + 0.1")
                          .where(building_analyses: { id: nil })
                          .where.not(featured: true) # Don't delete featured places
    
    orphaned_count = orphaned_places.count
    orphaned_places.destroy_all
    
    Rails.logger.info "Removed #{orphaned_count} orphaned places."
  end
  
  def self.generate_places_by_region
    Rails.logger.info "Generating places by geographic regions..."
    
    # Define major regions/cities with their approximate boundaries
    regions = {
      "Denver Metro Area" => { lat: 39.7392, lng: -104.9903, radius: 0.5 },
      "Boulder Area" => { lat: 40.0150, lng: -105.2705, radius: 0.3 },
      "Colorado Springs Area" => { lat: 38.8339, lng: -104.8214, radius: 0.4 },
      "Fort Collins Area" => { lat: 40.5853, lng: -105.0844, radius: 0.3 },
      "Aspen Area" => { lat: 39.1911, lng: -106.8175, radius: 0.2 },
      "Vail Area" => { lat: 39.6433, lng: -106.3781, radius: 0.2 }
    }
    
    created_places = []
    
    regions.each do |region_name, coords|
      # Skip if place already exists
      existing_place = Place.find_by(name: region_name)
      next if existing_place.present?
      
      # Count buildings in this region
      building_count = BuildingAnalysis.where(visible_in_library: true)
                                      .where(latitude: (coords[:lat] - coords[:radius])..(coords[:lat] + coords[:radius]))
                                      .where(longitude: (coords[:lng] - coords[:radius])..(coords[:lng] + coords[:radius]))
                                      .count
      
      next if building_count < 3 # Lower threshold for regions
      
      # Create place
      place = Place.new(
        name: region_name,
        latitude: coords[:lat],
        longitude: coords[:lng],
        zoom_level: 11,
        description: "Explore the architecture of #{region_name}. Discover #{building_count} analyzed buildings and their unique architectural styles.",
        published: true,
        featured: false
      )
      
      if place.save
        created_places << place
        Rails.logger.info "Created regional place: #{region_name} with #{building_count} buildings"
        
        # Queue content generation
        GeneratePlaceContentJob.perform_later(place.id)
      end
    end
    
    Rails.logger.info "Regional place generation complete. Created #{created_places.count} new places."
    created_places
  end
end 