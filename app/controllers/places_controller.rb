class PlacesController < ApplicationController
  before_action :set_custom_nav
  layout 'application'

  def show
    @place = Place.find_by(slug: params[:slug])
    
    if @place.nil?
      redirect_to root_path, alert: "Place not found"
      return
    end

    # Set up map variables
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @initial_center = [@place.longitude, @place.latitude]
    @initial_zoom = @place.zoom_level || 12
    
    # Get buildings for this place
    # Extract just the city name from the place name (e.g., "Denver" from "Denver, Colorado")
    city_name = @place.name.split(',').first.strip.downcase
    
    @building_analyses = BuildingAnalysis.where(visible_in_library: true)
                                        .where("LOWER(address) LIKE ?", "%#{city_name}%")
                                        .order(created_at: :desc)

    # Calculate style statistics for this place
    calculate_place_style_metrics
  end

  def index
    @places = Place.where(published: true).order(:name)
  end

  private

  def calculate_place_style_metrics
    style_counts = Hash.new(0)
    @building_analyses.each do |building|
      next unless building.h3_contents.present?
      
      begin
        styles = StyleNormalizer.normalize_array(
          JSON.parse(building.h3_contents || '[]')
        )
        styles.each { |style| style_counts[style] += 1 }
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse h3_contents for building #{building.id}: #{e.message}"
      end
    end
    
    @style_frequency = style_counts.sort_by { |_style, count| -count }
    @unique_style_count = style_counts.keys.count
    @buildings_submitted_count = @building_analyses.count
    @top_styles = @style_frequency.first(5) # Top 5 styles for this place
  end

  def set_custom_nav
    @custom_nav = true
  end
end 