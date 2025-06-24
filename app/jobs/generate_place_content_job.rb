class GeneratePlaceContentJob < ApplicationJob
  queue_as :default

  def perform(place_id)
    place = Place.find(place_id)
    generator = PlaceContentGenerator.new(place)
    generator.generate_content_and_images
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Place with ID #{place_id} not found"
  rescue => e
    Rails.logger.error "Error generating content for place #{place_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end 