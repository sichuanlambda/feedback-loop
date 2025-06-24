namespace :places do
  desc "Populate city field from addresses"
  task populate_cities: :environment do
    puts "Populating city field from addresses..."
    AutoPlaceGenerator.populate_city_from_address
    puts "City population complete!"
  end

  desc "Consolidate similar city names"
  task consolidate_cities: :environment do
    puts "Consolidating similar city names..."
    AutoPlaceGenerator.consolidate_city_names
    puts "City consolidation complete!"
  end

  desc "Regenerate all place slugs"
  task regenerate_slugs: :environment do
    puts "Regenerating all place slugs..."
    Place.regenerate_all_slugs!
    puts "Slug regeneration complete!"
  end

  desc "Automatically generate places from building analyses (cities with 3+ buildings by default)"
  task :auto_generate, [:min_buildings] => :environment do |task, args|
    min_buildings = (args[:min_buildings] || 3).to_i
    puts "Starting automatic place generation (min: #{min_buildings} buildings)..."
    
    places_before = Place.count
    AutoPlaceGenerator.generate_places_from_buildings(min_buildings)
    places_after = Place.count
    
    if places_after > places_before
      puts "Updating sitemap..."
      UpdateSitemapJob.perform_now
    end
    
    puts "Automatic place generation complete!"
  end

  desc "Generate places by geographic regions"
  task generate_regions: :environment do
    puts "Starting regional place generation..."
    AutoPlaceGenerator.generate_places_by_region
    puts "Regional place generation complete!"
  end

  desc "Update existing places with current building counts"
  task update_existing: :environment do
    puts "Updating existing places..."
    AutoPlaceGenerator.update_existing_places
    puts "Place updates complete!"
  end

  desc "Clean up orphaned places (no buildings)"
  task cleanup_orphaned: :environment do
    puts "Cleaning up orphaned places..."
    AutoPlaceGenerator.cleanup_orphaned_places
    puts "Cleanup complete!"
  end

  desc "Run all place generation tasks"
  task generate_all: :environment do
    puts "Running all place generation tasks..."
    
    places_before = Place.count
    AutoPlaceGenerator.consolidate_city_names
    AutoPlaceGenerator.generate_places_from_buildings(3)
    AutoPlaceGenerator.generate_places_by_region
    AutoPlaceGenerator.update_existing_places
    places_after = Place.count
    
    if places_after > places_before
      puts "Updating sitemap..."
      UpdateSitemapJob.perform_now
    end
    
    puts "All place generation tasks complete!"
  end

  desc "Show cities with 3+ buildings that could become places"
  task :show_candidates, [:min_buildings] => :environment do |task, args|
    min_buildings = (args[:min_buildings] || 3).to_i
    
    # First populate and consolidate cities if needed
    AutoPlaceGenerator.populate_city_from_address
    AutoPlaceGenerator.consolidate_city_names
    
    city_building_counts = BuildingAnalysis.where(visible_in_library: true)
                                          .where.not(city: [nil, '', 'N/A'])
                                          .group(:city)
                                          .count
    
    candidates = city_building_counts.select { |city, count| count >= min_buildings }
    
    if candidates.empty?
      puts "No cities found with #{min_buildings}+ buildings."
      puts "\nCities with buildings (less than #{min_buildings}):"
      city_building_counts.sort_by { |city, count| -count }.each do |city, count|
        puts "  #{city}: #{count} buildings"
      end
    else
      puts "Cities with #{min_buildings}+ buildings (potential places):"
      candidates.sort_by { |city, count| -count }.each do |city, count|
        existing = Place.find_by(name: city)
        status = existing ? "✓ EXISTS" : "NEW"
        puts "  #{city}: #{count} buildings (#{status})"
      end
    end
  end

  desc "Show current place statistics"
  task stats: :environment do
    total_places = Place.count
    published_places = Place.published.count
    featured_places = Place.featured.count
    places_with_images = Place.with_images.count
    places_with_content = Place.where.not(content: [nil, '']).count
    
    puts "Place Statistics:"
    puts "  Total places: #{total_places}"
    puts "  Published: #{published_places}"
    puts "  Featured: #{featured_places}"
    puts "  With images: #{places_with_images}"
    puts "  With content: #{places_with_content}"
    
    puts "\nTop places by building count:"
    Place.find_each do |place|
      building_count = place.building_analyses_in_place.count
      if building_count > 0
        puts "  #{place.name}: #{building_count} buildings"
      end
    end
  end
end 