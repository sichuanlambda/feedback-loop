require 'aws-sdk-s3'
require 'net/http'
require 'json'
require 'nokogiri'
require 'image_optim'

class ArchitectureExplorerController < ApplicationController
  before_action :authenticate_user!, except: [:building_library]
  before_action :set_custom_nav

  def new
    # Renders the form for uploading an image
  end


  def create
    Rails.logger.debug "Processing the uploaded image..."
    Rails.logger.debug "Form submission received with params: #{params.inspect}"

    uploaded_image = params[:image]
    image_url = nil  # Initialize variable to capture the image URL

    # Handle directly uploaded images
    if uploaded_image.present?
      image_url = upload_image_to_s3(uploaded_image)
    # Handle images fetched from a street view URL
    elsif params[:street_view_url].present?
      uploaded_image = fetch_street_view_image(params[:street_view_url])
      image_url = upload_image_to_s3(uploaded_image) if uploaded_image
    end

    # Redirect if no image was processed
    if uploaded_image.blank? || image_url.blank?
      redirect_to root_path, alert: "No image uploaded or address provided"
      return
    end

    # Process the building image (assuming this method exists and works correctly)
    analysis_result = process_building_image(uploaded_image)

    # Proceed only if analysis is successful
    if analysis_result && analysis_result[:html_content].present?
      # Extract H3 contents from the analysis result
      h3_contents = extract_h3s(analysis_result[:html_content])

      # Create a new BuildingAnalysis record with all necessary data
      new_analysis = BuildingAnalysis.create(
        html_content: analysis_result[:html_content],
        user: current_user, # Assuming you have a method or devise helper to get the current user
        image_url: image_url, # Use the S3 URL obtained from the image upload
        h3_contents: h3_contents.to_json,
        visible_in_library: true,
        address: params[:address].presence || "N/A"
      )

      # Redirect to the show page of the analysis if creation is successful
      if new_analysis.persisted?
        Rails.logger.debug "New analysis created successfully with ID: #{new_analysis.id}"
        redirect_to architecture_explorer_show_path(id: new_analysis.id)
      else
        # Handle case where saving the analysis fails
        Rails.logger.debug "Failed to save new analysis. Errors: #{new_analysis.errors.full_messages.join(", ")}"
        redirect_to root_path, alert: "Analysis failed: #{new_analysis.errors.full_messages.join(", ")}"
      end
    else
      # Handle case where analysis does not produce expected results
      redirect_to root_path, alert: "Analysis failed"
    end
  rescue => e
    # General rescue for unexpected exceptions, logging the error for debugging
    Rails.logger.error "Exception in create action: #{e.message}"
    redirect_to root_path, alert: "Unexpected error occurred."
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
      temp_image
    rescue => e
      Rails.logger.error "Failed to fetch street view image: #{e.message}"
      nil
    end
  end


  def address_search
    # Any setup needed for the view can be added here
  end
  def fetch_street_view_image(address)
    # Construct the URL for the Google Street View API. Replace YOUR_API_KEY with your actual Google API key.
    # Note: Ensure you handle URL encoding for the address to ensure it's a valid URL.
    api_key = Rails.application.credentials.google_maps[:api_key] # Assuming your API key is stored in Rails credentials.
    url = "https://maps.googleapis.com/maps/api/streetview?size=600x400&location=#{URI.encode_www_form_component(address)}&key=#{api_key}"

    # Fetch the image using open-uri
    begin
      image_data = URI.open(url).read
      # Create a Tempfile to hold the image data. Tempfile automatically deletes the file when the object is garbage collected.
      temp_image = Tempfile.new(['street_view', '.jpg'])
      temp_image.binmode # Ensure binary mode for non-text data
      temp_image.write(image_data)
      temp_image.rewind # Move file pointer back to the beginning of the file

      return temp_image
    rescue OpenURI::HTTPError => e
      Rails.logger.error "Failed to fetch street view image: #{e.message}"
      return nil
    end
  end

  def show
    @building_analysis = BuildingAnalysis.find_by(id: params[:id])

    if @building_analysis
      # Move the @is_shared assignment here, after confirming @building_analysis is not nil
      @is_shared = @building_analysis.visible_in_library
      @html_content = @building_analysis.html_content
      @image_url = @building_analysis.image_url # Make the image URL available in the view

      # Extract H3 contents from the HTML content
      @h3_contents = extract_h3s(@html_content)
    else
      redirect_to root_path, alert: "Analysis not found"
    end
  end

  def extract_h3s(html_content)
    doc = Nokogiri::HTML(html_content)
    doc.search('h3').map(&:text).uniq # .uniq ensures no duplicates
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
      # Fetches records that contain the search term in `h3_contents` and are visible in the library
      @analyzed_buildings = BuildingAnalysis.where("LOWER(h3_contents) LIKE ? AND visible_in_library = ?", "%#{search_term}%", true)
    else
      # Fetches all records that are visible in the library when there is no search term
      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
    end
    # Orders the results by creation date in descending order for both cases
    @analyzed_buildings = @analyzed_buildings.order(created_at: :desc)

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

    # Handling the search functionality
    if params[:search].present?
      search_term = params[:search].downcase
      @analyzed_buildings = BuildingAnalysis.where("LOWER(h3_contents) LIKE ? AND visible_in_library = ?", "%#{search_term}%", true)
    else
      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
    end
    @analyzed_buildings = @analyzed_buildings.order(created_at: :desc)

    render 'architecture_explorer/building_library'
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
    @buildings = Building.where('styles @> ?', "{#{@style_name}}") # Assuming styles are stored in an array column
    render :indexturn
  end

  def by_location
    # Check if a location name is provided and downcase it if present
    @location_name = params[:location_name]&.downcase
    @style_frequency = [] # Initialize as an empty array to prevent nil errors in the view

    # Adjust the query based on the provided parameters
    if @location_name.present?
      # Query for buildings by location
      @analyzed_buildings = BuildingAnalysis.where("LOWER(address) LIKE ? AND visible_in_library = ?", "%#{@location_name}%", true)
    elsif params[:search].present?
      # Query for buildings by style if 'search' parameter is used instead
      search_term = params[:search].downcase
      @analyzed_buildings = BuildingAnalysis.where("LOWER(h3_contents) LIKE ? AND visible_in_library = ?", "%#{search_term}%", true)
    else
      # Default case if no specific filter is applied
      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
    end

    # Extract and clean styles for display and filtering
    all_styles = @analyzed_buildings.pluck(:h3_contents).map do |h3_content|
      JSON.parse(h3_content || '[]').map { |style| style.gsub(/[^\w\s]/, '').gsub(/\d/, '').strip }
    end.flatten.uniq.sort
    @architecture_styles = all_styles
    @style_frequency ||= {}

  render 'denver'
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
  end

  def remove_code_block_markers(html_content)
    html_content.gsub(/^```html\n/, "").gsub(/\n```$/, "")
  end

  def upload_image_to_s3(uploaded_file)
    return nil if uploaded_file.blank?

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    file_name = uploaded_file.respond_to?(:original_filename) ? uploaded_file.original_filename : "fetched_street_view_#{Time.now.to_i}.jpg"
    obj = s3.bucket('architecture-explorer').object("uploads/#{file_name}")

    # Initialize ImageOptim with only the desired optimizers enabled
    image_optim = ImageOptim.new(
      pngout: false,
      svgo: false,
      pngcrush: false,
      advpng: false,
      oxipng: false,
      jhead: false,
      jpegoptim: {max_quality: 20},
      pngquant: {quality: 100..120}
    )

    # Attempt to optimize the image and capture the optimized image path
    optimized_image_path = image_optim.optimize_image(uploaded_file.path)

    # Ensure we're using a string path for the optimized image, if available
    file_path_to_upload = optimized_image_path ? optimized_image_path.to_path : uploaded_file.path

    # Upload the file to S3 and check for success
    if obj.upload_file(file_path_to_upload)
      Rails.logger.debug "Upload to S3 completed: #{obj.public_url}"
      return obj.public_url
    else
      Rails.logger.error "Failed to upload image to S3"
      return nil
    end
  rescue StandardError => e
    Rails.logger.error "Exception occurred during image upload: #{e.message}"
    nil
  end


  def set_custom_nav
    @custom_nav = true
  end

end
