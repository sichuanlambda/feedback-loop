class Admin::PlacesController < ApplicationController
  include AdminAuthorization
  before_action :set_place, only: [:show, :edit, :update, :destroy, :generate_content]

  def index
    @places = Place.order(:name)
  end

  def show
  end

  def new
    @place = Place.new
  end

  def edit
  end

  def create
    @place = Place.new(place_params)

    if @place.save
      # Trigger content generation in background
      GeneratePlaceContentJob.perform_later(@place.id) if @place.needs_content_generation?
      
      redirect_to admin_place_path(@place), notice: 'Place was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @place.update(place_params)
      # Update sitemap if published status changed
      if @place.saved_change_to_published?
        UpdateSitemapJob.perform_later
      end
      
      redirect_to admin_place_path(@place), notice: 'Place was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @place.destroy
    redirect_to admin_places_path, notice: 'Place was successfully deleted.'
  end

  def generate_content
    GeneratePlaceContentJob.perform_later(@place.id)
    redirect_to admin_place_path(@place), notice: 'Content generation has been queued. Check back in a few minutes.'
  end

  def auto_generate
    AutoPlaceGenerationJob.perform_later('cities')
    redirect_to admin_places_path, notice: 'Automatic place generation has been queued. Check back in a few minutes.'
  end

  def generate_all
    AutoPlaceGenerationJob.perform_later('all')
    redirect_to admin_places_path, notice: 'All place generation tasks have been queued. Check back in a few minutes.'
  end

  def preview_generation
    # Populate and consolidate cities first
    AutoPlaceGenerator.populate_city_from_address
    AutoPlaceGenerator.consolidate_city_names
    
    # Get potential places
    city_building_counts = BuildingAnalysis.where(visible_in_library: true)
                                          .where.not(city: [nil, '', 'N/A'])
                                          .group(:city)
                                          .count
    
    min_buildings = (params[:min_buildings] || 3).to_i
    @candidate_places = city_building_counts.select { |city, count| count >= min_buildings }
    
    # Check which ones already exist
    @candidate_places.each do |city_name, building_count|
      existing_place = Place.find_by(name: city_name)
      if existing_place
        @candidate_places[city_name] = { count: building_count, exists: true, existing_place: existing_place }
      else
        @candidate_places[city_name] = { count: building_count, exists: false }
      end
    end
  end

  def confirm_generation
    selected_cities = params[:selected_cities] || []
    min_buildings = (params[:min_buildings] || 3).to_i
    
    created_count = 0
    selected_cities.each do |city_name|
      # Skip if place already exists
      next if Place.find_by(name: city_name)
      
      # Get sample building to extract coordinates
      sample_building = BuildingAnalysis.where(city: city_name, visible_in_library: true).first
      next unless sample_building&.latitude && sample_building&.longitude
      
      # Count buildings
      building_count = BuildingAnalysis.where(city: city_name, visible_in_library: true).count
      next if building_count < min_buildings
      
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
        created_count += 1
        # Queue content generation
        GeneratePlaceContentJob.perform_later(place.id)
      end
    end
    
    # Update sitemap if any places were created
    if created_count > 0
      UpdateSitemapJob.perform_later
    end
    
    redirect_to admin_places_path, notice: "Successfully created #{created_count} new places."
  end

  def merge_duplicates
    # Find duplicate places by similar names
    @duplicate_groups = find_duplicate_places
  end

  def perform_merge
    target_place_id = params[:target_place_id]
    place_ids_to_merge = params[:place_ids_to_merge] || []
    
    target_place = Place.find(target_place_id)
    
    place_ids_to_merge.each do |place_id|
      place_to_merge = Place.find(place_id)
      next if place_to_merge.id == target_place.id
      
      # Merge building associations (if any)
      # For now, just delete the duplicate place
      place_to_merge.destroy
    end
    
    redirect_to admin_places_path, notice: 'Duplicate places merged successfully.'
  end

  private

  def set_place
    @place = Place.find_by(slug: params[:id]) || Place.find(params[:id])
  end

  def place_params
    params.require(:place).permit(:name, :slug, :latitude, :longitude, :zoom_level, 
                                 :description, :content, :published, :featured, 
                                 :meta_title, :meta_description, :hero_image_url, 
                                 :hero_image_alt, :representative_image_url, :image_source)
  end

  def find_duplicate_places
    places = Place.all
    duplicate_groups = []
    
    places.each do |place|
      # Find places with similar names
      similar_places = places.select do |p| 
        p.id != place.id && 
        (p.name.downcase.include?(place.name.downcase) || 
         place.name.downcase.include?(p.name.downcase))
      end
      
      if similar_places.any?
        group = [place] + similar_places
        # Only add if this group hasn't been added yet
        unless duplicate_groups.any? { |g| g.any? { |p| p.id == place.id } }
          duplicate_groups << group
        end
      end
    end
    
    duplicate_groups
  end
end 