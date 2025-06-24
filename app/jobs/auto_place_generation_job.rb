class AutoPlaceGenerationJob < ApplicationJob
  queue_as :default

  def perform(generation_type = 'cities')
    case generation_type
    when 'cities'
      AutoPlaceGenerator.generate_places_from_buildings
    when 'regions'
      AutoPlaceGenerator.generate_places_by_region
    when 'update'
      AutoPlaceGenerator.update_existing_places
    when 'cleanup'
      AutoPlaceGenerator.cleanup_orphaned_places
    when 'all'
      AutoPlaceGenerator.generate_places_from_buildings
      AutoPlaceGenerator.generate_places_by_region
      AutoPlaceGenerator.update_existing_places
    else
      Rails.logger.error "Unknown generation type: #{generation_type}"
    end
  rescue => e
    Rails.logger.error "Error in auto place generation: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end 