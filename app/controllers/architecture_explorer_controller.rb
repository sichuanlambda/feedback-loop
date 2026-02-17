require 'aws-sdk-s3'
require 'net/http'
require 'json'
require 'nokogiri'
require 'open-uri'

class ArchitectureExplorerController < ApplicationController
  before_action :authenticate_user!, except: [:building_library, :by_location, :style_finder, :address_search, :show, :map]
  before_action :set_custom_nav
  # include BuildingAnalysisProcessor

  # Use the default layout for most actions
  layout 'application'

  # Use the custom layout only for the new map-based views
  layout :determine_layout

  # Existing actions
  def address_search
    # Any setup needed for the view can be added here
  end

  def building_library
    # Adjust the method to fetch images for all users or a generic set if no user is logged in
    if user_signed_in?
      # Fetch images analyzed by the current user
      @user_analyzed_images = BuildingAnalysis.where(user: current_user).order(created_at: :desc)
      # Get the frequency of each style for the current user
      style_frequency = BuildingAnalysis.style_frequency(current_user.id)
      @style_frequency = style_frequency.sort_by { |style, frequency| -frequency }
      @unique_style_count = @style_frequency.length
      @buildings_submitted_count = BuildingAnalysis.where(user: current_user).count
    else
      # Set variables to nil or default values since no user is logged in
      @user_analyzed_images = nil
      @style_frequency = nil
      @unique_style_count = nil
      @buildings_submitted_count = nil
    end

    if params[:search].present?
      search_term = params[:search].downcase
      @analyzed_buildings = BuildingAnalysis.where("LOWER(h3_contents) LIKE ? AND visible_in_library = ?", "%#{search_term}%", true)
    else
      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
    end
    @analyzed_buildings = @analyzed_buildings.order(created_at: :desc).page(params[:page]).per(24)

    # Extract all styles from h3_contents, clean them, and assign to @architecture_styles
    all_styles = BuildingAnalysis.pluck(:h3_contents).compact.map do |h3_content|
      begin
        JSON.parse(h3_content || '[]').map { |style| style.gsub(/[^\w\s]/, '').gsub(/\d/, '').strip }
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON from h3_contents: #{e.message}"
        []
      end
    end.flatten.uniq.sort.first(15)
    @architecture_styles = all_styles

    render 'architecture_explorer/building_library', layout: 'application'
  end

  def remove_from_library
    building_analysis = BuildingAnalysis.find(params[:id])
    if building_analysis.update(visible_in_library: false)
      redirect_to architecture_explorer_show_path(id: building_analysis.id), notice: 'Removed from library successfully.'
    else
      redirect_to architecture_explorer_show_path(id: building_analysis.id), alert: 'Failed to remove from library.'
    end
  end

  def add_to_library
    @building_analysis = BuildingAnalysis.find(params[:id])

    if @building_analysis.update(visible_in_library: true)
      redirect_to architecture_explorer_show_path(id: @building_analysis.id), notice: 'Building successfully shared in library.'
    else
      redirect_to architecture_explorer_show_path(id: @building_analysis.id), alert: 'Unable to share building in library.'
    end
  end

  def update
    @building_analysis = BuildingAnalysis.find(params[:id])
    if @building_analysis.update(building_analysis_params)
      redirect_to architecture_explorer_show_path(id: @building_analysis.id), notice: 'Address updated successfully.'
    else
      render :show, alert: 'Failed to update address.'
    end
  end

  def by_style
    @style_name = params[:style_name]

    # Find buildings whose normalized styles include this style name
    # We still use LIKE for the DB query, but normalize the display
    canonical = StyleNormalizer.normalize(@style_name)
    
    # Search for buildings that match either the canonical name or any of its variants
    variants = StyleNormalizer::CANONICAL_STYLES[canonical] || [@style_name.downcase]
    conditions = variants.map { |v| "LOWER(h3_contents) LIKE ?" }
    values = variants.map { |v| "%#{v}%" }
    
    @analyzed_buildings = BuildingAnalysis
      .where(visible_in_library: true)
      .where(conditions.join(' OR '), *values)
      .order(created_at: :desc)

    @style_name = canonical  # Display the canonical name

    @architecture_styles = BuildingAnalysis.pluck(:h3_contents).compact.flat_map do |h3_content|
      begin
        StyleNormalizer.normalize_array(JSON.parse(h3_content || '[]'))
      rescue JSON::ParserError
        []
      end
    end.uniq.sort.first(20)

    render 'architecture_explorer/building_library', layout: 'application'
  end

  def by_location
    @location_name = params[:location_name]&.downcase
    @style_frequency = []
    @unique_style_count = 0
    @buildings_submitted_count = 0

    # Special handling for Netherlands
    if @location_name == 'the_netherlands'
      netherlands_box = [
        [50.75, 3.2],  # Southwest corner
        [53.75, 7.22]  # Northeast corner
      ]

      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
        .within_bounding_box(netherlands_box)

      Rails.logger.info "Found #{@analyzed_buildings.count} buildings in the Netherlands"
      Rails.logger.info "Sample addresses: #{@analyzed_buildings.limit(3).pluck(:address)}"
    else
      # Original location-based query for other locations
      @analyzed_buildings = BuildingAnalysis.where(
        "LOWER(address) LIKE ? AND visible_in_library = ?",
        "%#{@location_name}%",
        true
      )
    end

    # Calculate Style Frequency
    style_counts = Hash.new(0)
    @analyzed_buildings.each do |building|
      styles = JSON.parse(building.h3_contents || '[]').map { |style| style.gsub(/\s*\d+%$/, '') }
      styles.each { |style| style_counts[style] += 1 }
    end
    @style_frequency = style_counts.sort_by { |_style, count| -count }

    # Count unique styles and total buildings analyzed
    @unique_style_count = style_counts.keys.count
    @buildings_submitted_count = @analyzed_buildings.count

    # Extract and clean styles for the sidebar or filter
    @architecture_styles = style_counts.keys.sort
    render 'denver'
  end

  def show
    @building_analysis = BuildingAnalysis.find_by(id: params[:id])

    if @building_analysis
      # Move the @is_shared assignment here, after confirming @building_analysis is not nil
      @is_shared = @building_analysis.visible_in_library
      @html_content = @building_analysis.html_content
      @image_url = @building_analysis.image_url # Make the image URL available in the view

      # Use stored normalized styles, falling back to re-extraction from HTML
      if @building_analysis.h3_contents.present?
        begin
          @h3_contents = StyleNormalizer.normalize_array(
            JSON.parse(@building_analysis.h3_contents)
          )
        rescue JSON::ParserError
          @h3_contents = []
        end
      else
        h3_contents = extract_h3s(@html_content)
        @h3_contents = StyleNormalizer.normalize_array(clean_h3_contents(h3_contents))
      end
      Rails.logger.debug "Normalized H3 contents for show: #{@h3_contents.inspect}"
    else
      redirect_to root_path, alert: "Analysis not found"
    end
  end

  def extract_h3s(html_content)
    doc = Nokogiri::HTML(html_content)
    h3s = doc.css('h3').map(&:text).map(&:strip).uniq # Extract H3 text, strip whitespace, and remove duplicates

    # Log the extracted H3 contents for debugging
    Rails.logger.debug "Extracted H3 contents: #{h3s.inspect}"

    h3s # Return the array of H3 contents
  end

  def clean_h3_contents(h3_contents)
    h3_contents.map { |content| content.gsub(/[^\w\s]/, '').gsub(/\d/, '').strip }
  end

  def fetch_street_view_image(address)
    api_key = Rails.application.credentials.google_maps[:api_key]
    url = "https://maps.googleapis.com/maps/api/streetview?size=600x400&location=#{URI.encode_www_form_component(address)}&key=#{api_key}"

    begin
      image_data = URI.open(url).read
      temp_image = Tempfile.new(["street_view", ".jpg"])
      temp_image.binmode
      temp_image.write(image_data)
      temp_image.rewind

      return temp_image
    rescue => e
      Rails.logger.error "Failed to fetch street view image: #{e.message}"
      nil
    end
  end

  def new
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
  end

  def create
    Rails.logger.debug "Create action called with params: #{params.inspect}"

    image_url = if params[:image].present?
                  upload_image_to_s3(params[:image])
                elsif params[:external_image_url].present?
                  params[:external_image_url]
                elsif params[:previewed_image_url].present?
                  params[:previewed_image_url]
                end

    if image_url.blank?
      redirect_to root_path, alert: "No image uploaded or address provided"
      return
    end

    begin
      address = params[:address].presence || "N/A"

      # Create record immediately (html_content nil triggers "Hang tight" on show page)
      @building_analysis = BuildingAnalysis.create!(
        user: current_user,
        image_url: image_url,
        visible_in_library: true,
        address: address,
        name: params[:building_name].presence
      )

      # Enqueue background job for GPT analysis (avoids R12 timeouts)
      ProcessBuildingAnalysisJob.perform_later(@building_analysis.id, image_url, address)

      redirect_to architecture_explorer_show_path(id: @building_analysis.id), notice: "Analysis started! Results will appear shortly."
    rescue => e
      Rails.logger.error "Error in create action: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to root_path, alert: "An error occurred while processing your request."
    end
  end

  def status
    building_analysis = BuildingAnalysis.find_by(id: params[:id])

    if building_analysis&.html_content.present?
      render json: { status: 'completed', html_content: building_analysis.html_content, h3_contents: building_analysis.h3_contents }
    else
      render json: { status: 'processing' }
    end
  end

  # New map-based view actions
  def map
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.all.map do |analysis|
      {
        id: analysis.id,
        latitude: analysis.latitude,
        longitude: analysis.longitude,
        address: analysis.address,
        city: analysis.city,
        h3_contents: JSON.parse(analysis.h3_contents || '[]'),
        street_view_url: analysis.street_view_url,
        image_url: analysis.image_url,
        user_id: analysis.user_id,
        created_at: analysis.created_at
      }
    end
    @places = Place.published.select(:name, :slug, :latitude, :longitude, :zoom_level).map do |place|
      { name: place.name, slug: place.slug, latitude: place.latitude.to_f, longitude: place.longitude.to_f, zoom_level: place.zoom_level }
    end
  end

  def dutch_architecture
    @initial_center = [4.9041, 52.3676]  # Amsterdam coordinates
    @initial_zoom = 7  # Zoom level to show most of the Netherlands
    @preset_styles = ['Dutch Renaissance', 'Dutch Baroque', 'Amsterdam School']
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.where(style: @preset_styles)
  end

  def netherlands
    @initial_center = [5.2913, 52.1326]  # Center of the Netherlands
    @initial_zoom = 7
    @preset_styles = []  # Show all styles in the Netherlands
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]

    # Define Netherlands bounding box coordinates
    netherlands_box = [
      [50.75, 3.2],  # Southwest corner
      [53.75, 7.22]  # Northeast corner
    ]

    @building_analyses = BuildingAnalysis.where(visible_in_library: true)
      .within_bounding_box(netherlands_box)

    Rails.logger.info "Found #{@building_analyses.count} buildings in the Netherlands"
    Rails.logger.info "Sample coordinates: #{@building_analyses.limit(3).pluck(:latitude, :longitude)}"
  end

  def denver
    @initial_center = [-104.9903, 39.7392]  # Denver coordinates
    @initial_zoom = 12
    @preset_styles = []  # No style filter, show all styles in Denver
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.where(city: 'Denver')
  end

  def new_york_city
    @initial_center = [-74.0060, 40.7128]  # NYC coordinates
    @initial_zoom = 12
    @preset_styles = []  # No style filter, show all styles in NYC
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.where(city: 'New York City')
  end

  def washington_dc
    @initial_center = [-77.0369, 38.9072]  # DC coordinates
    @initial_zoom = 12
    @preset_styles = []  # No style filter, show all styles in DC
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.where(city: 'Washington')
  end

  def boston
    @initial_center = [-71.0589, 42.3601]  # Boston coordinates
    @initial_zoom = 12
    @preset_styles = []  # No style filter, show all styles in Boston
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.where(city: 'Boston')
  end

  def brutalist_architecture
    @initial_center = [-3.4359, 55.3781]  # Roughly centered on Europe
    @initial_zoom = 4  # Zoomed out to show a large area
    @preset_styles = ['Brutalist']
    @mapbox_access_token = Rails.application.credentials.mapbox[:access_token]
    @building_analyses = BuildingAnalysis.where(style: 'Brutalist')
  end

  def denver_architecture
    @places = []  # Temporary empty array
    render 'architecture_explorer/map_places_and_styles/denver_architecture'
  end

  def development_estimations
    # Just renders the view
  end

  def generate_development_estimation
    image_url = params[:previewed_image_url]
    address = params[:address]
    custom_prompt = params[:custom_prompt]
    analysis_mode = params[:analysis_mode]

    begin
      gpt_service = GptService.new
      result = gpt_service.send_development_estimation(image_url, address, custom_prompt, analysis_mode)

      if result && result["analysis"]
        render json: {
          success: true,
          estimation: result["analysis"]
        }
      else
        render json: {
          success: false,
          error: "Failed to generate estimation"
        }
      end
    rescue => e
      Rails.logger.error "Development Estimation Error: #{e.message}"
      render json: {
        success: false,
        error: "Failed to generate estimation: #{e.message}"
      }
    end
  end

  def analyze_style_preferences
    styles = params[:styles]
    
    if styles.blank?
      render json: { success: false, error: "No styles provided" }
      return
    end

    begin
      gpt_service = GptService.new
      result = gpt_service.analyze_style_preferences(styles)
      
      if result
        render json: {
          success: true,
          title: result[:title],
          summary: result[:summary],
          top_styles: result[:top_styles]
        }
      else
        render json: {
          success: false,
          error: "Failed to generate style summary"
        }
      end
    rescue => e
      Rails.logger.error "Style Analysis Error: #{e.message}"
      render json: {
        success: false,
        error: "Failed to analyze styles: #{e.message}"
      }
    end
  end

  def building_data
    building_analysis = BuildingAnalysis.find_by(id: params[:id])
    
    if building_analysis
      render json: {
        success: true,
        id: building_analysis.id,
        image_url: building_analysis.image_url,
        address: building_analysis.address || "Building ##{building_analysis.id}",
        h3_contents: building_analysis.h3_contents,
        html_content: building_analysis.html_content
      }
    else
      render json: {
        success: false,
        error: "Building not found"
      }
    end
  end

  private

  def calculate_style_frequency(building_analyses)
    # Your logic to calculate style frequency based on the provided analyses
    # This is a placeholder; you'll need to implement the actual calculation based on your application's needs
    {}
  end

  private

  def building_analysis_params
    params.require(:building_analysis).permit(:address, :image, :street_view_url)
  end

  def process_building_image(uploaded_image)
    # Upload the image to S3 and get the URL
    image_url = upload_image_to_s3(uploaded_image)
    return { html_content: nil } if image_url.nil?

    # Interact with GPT service using the image URL
    gpt_response = GptService.new.send_building_analysis(image_url)

    # Extract HTML content if present
    if gpt_response.present?
      html_content = gpt_response["analysis"]
      html_content = CGI.unescapeHTML(html_content)
      html_content = remove_code_block_markers(html_content)
      { html_content: html_content }
    else
      Rails.logger.error "GPT did not return a response"
      nil
    end
  rescue => e
    Rails.logger.error "Error in processing building image: #{e.message}"
    nil
  end

  def create_new_analysis(analysis_result)
    BuildingAnalysis.create(
      user: current_user,
      html_content: analysis_result[:html_content],
      image_url: analysis_result[:image_url],
      h3_contents: analysis_result[:h3_contents],
      visible_in_library: true,
      address: params[:address].presence || "N/A"
    )
    if params[:previewed_image_url].present?
      # Logic to handle the image from the submitted URL
      image_url = params[:previewed_image_url]
      # You might need to download the image from this URL before uploading to S3
    end
  end

  def remove_code_block_markers(html_content)
    html_content.gsub(/^```html\n/, "").gsub(/\n```$/, "")
  end

  def upload_image_to_s3(input)
    s3 = Aws::S3::Resource.new(region: 'us-east-2')

    # # Use the globally configured ImageOptim instance
    # image_optim = ImageOptim.new

    if input.is_a?(String) && input.start_with?('http')
      # Input is a URL, download the image first
      image_data = URI.open(input)
      file_name = "downloaded_image_#{Time.now.to_i}.jpg"
      temp_file_path = image_data.path
    elsif input.respond_to?(:path)
      # Input is a file or a Tempfile, directly use it
      file_name = input.original_filename if input.respond_to?(:original_filename)
      temp_file_path = input.path
    else
      Rails.logger.error "Invalid input for upload_image_to_s3"
      return nil
    end

    # Optimize the image and determine the path to upload
    # optimized_image_path = image_optim.optimize_image!(temp_file_path)
    # file_path_to_upload = optimized_image_path ? optimized_image_path.to_path : temp_file_path

    # Use temp_file_path directly
    file_path_to_upload = temp_file_path

    # Create the object key for S3 and upload the file
    object_key = "uploads/#{file_name}"
    obj = s3.bucket('architecture-explorer').object(object_key)
    success = obj.upload_file(file_path_to_upload)

    # Close the image_data if it's opened from a URL
    image_data.close if image_data && image_data.respond_to?(:close)

    if success
      Rails.logger.debug "Upload to S3 completed: #{obj.public_url}"
      return obj.public_url
    else
      Rails.logger.error "Failed to upload image to S3"
      return nil
    end
  rescue StandardError => e
    Rails.logger.error "Exception during upload to S3: #{e.message}"
    return nil
  end

  def set_custom_nav
    @custom_nav = true
  end

  def determine_layout
    if action_name.in?(%w[map dutch_architecture netherlands denver new_york_city washington_dc boston brutalist_architecture])
      'architecture_explorer'
    else
      'application'
    end
  end

  def normalize_h3_contents(h3_contents)
    StyleNormalizer.normalize_array(h3_contents)
  end

  def styles_index
    style_counts = Hash.new(0)
    BuildingAnalysis.where(visible_in_library: true).pluck(:h3_contents).compact.each do |h3_content|
      begin
        styles = StyleNormalizer.normalize_array(JSON.parse(h3_content))
        styles.each { |style| style_counts[style] += 1 }
      rescue JSON::ParserError
        next
      end
    end
    @styles_with_counts = style_counts.sort_by { |_style, count| -count }
    @total_buildings = BuildingAnalysis.where(visible_in_library: true).count
  end

  def style_show
    @style_name = StyleNormalizer.normalize(params[:style_name])
    variants = StyleNormalizer::CANONICAL_STYLES[@style_name] || [params[:style_name].downcase]
    conditions = variants.map { |_v| "LOWER(h3_contents) LIKE ?" }
    values = variants.map { |v| "%#{v}%" }

    @analyzed_buildings = BuildingAnalysis
      .where(visible_in_library: true)
      .where(conditions.join(' OR '), *values)
      .order(created_at: :desc)

    # Cities that have this style
    @cities = @analyzed_buildings.map { |b| b.address.to_s.split(',').last(2).first.to_s.strip }.reject(&:blank?).tally.sort_by { |_c, n| -n }

    # Matching places
    @places = Place.where("LOWER(name) IN (?)", @cities.map { |c, _| c.downcase }).limit(12) if defined?(Place)
  end

  def calculate_style_metrics
    style_counts = Hash.new(0)
    @analyzed_buildings.each do |building|
      styles = StyleNormalizer.normalize_array(
        JSON.parse(building.h3_contents || '[]')
      )
      styles.each { |style| style_counts[style] += 1 }
    end
    @style_frequency = style_counts.sort_by { |_style, count| -count }
    @unique_style_count = style_counts.keys.count
    @buildings_submitted_count = @analyzed_buildings.count
    @architecture_styles = style_counts.keys.sort
  end

  def call_gpt_with_image(prompt, image_url)
    # Implement your GPT API call here
    # Similar to your existing GPT integration
  end
end
