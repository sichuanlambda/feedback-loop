require 'aws-sdk-s3'
require 'net/http'
require 'json'
require 'nokogiri'
require 'image_optim'
require 'open-uri'

class ArchitectureExplorerController < ApplicationController
  before_action :authenticate_user!, except: [:building_library, :by_location]
  before_action :set_custom_nav

  def new
    # Renders the form for uploading an image
  end


  def create
    Rails.logger.debug "Processing the uploaded image..."
    Rails.logger.debug "Form submission received with params: #{params.inspect}"

    image_url = nil

    if params[:image].present?
      uploaded_image = params[:image]
      image_url = upload_image_to_s3(uploaded_image)
    elsif params[:previewed_image_url].present?
      address = params[:address]
      fetched_image = fetch_street_view_image(address)
      image_url = upload_image_to_s3(fetched_image) if fetched_image
    end

    if image_url.blank?
      redirect_to root_path, alert: "No image uploaded or address provided"
      return
    end

    analysis_result = process_building_image(image_url)

    if analysis_result && analysis_result[:html_content].present?
      # Adjust here to ensure h3_contents are extracted and saved correctly
      h3_contents = extract_h3s(analysis_result[:html_content])
      new_analysis = BuildingAnalysis.create(
        html_content: analysis_result[:html_content],
        user: current_user,
        image_url: image_url,
        h3_contents: h3_contents.to_json, # Ensure this line is correct
        visible_in_library: true,
        address: params[:address].presence || "N/A"
      )

      if new_analysis.persisted?
        redirect_to architecture_explorer_show_path(id: new_analysis.id)
      else
        redirect_to root_path, alert: "Analysis failed: #{new_analysis.errors.full_messages.join(", ")}"
      end
    else
      redirect_to root_path, alert: "Analysis failed"
    end
  rescue => e
    Rails.logger.error "Exception in create action: #{e.message}"
    redirect_to root_path, alert: "Unexpected error occurred."
  end


  def address_search
    # Any setup needed for the view can be added here
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
    doc.search('h3').map do |h3|
      # Remove special characters and numbers from each H3 text, then strip to remove leading/trailing whitespace
      h3.text.gsub(/[^\w\s]/, '').gsub(/\d/, '').strip
    end.uniq # Ensure no duplicates
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
    @location_name = params[:location_name]&.downcase
    @style_frequency = []
    @unique_style_count = 0
    @buildings_submitted_count = 0

    # Adjust the query based on the provided parameters
    if @location_name.present?
      @analyzed_buildings = BuildingAnalysis.where("LOWER(address) LIKE ? AND visible_in_library = ?", "%#{@location_name}%", true)
    elsif params[:search].present?
      search_term = params[:search].downcase
      @analyzed_buildings = BuildingAnalysis.where("LOWER(h3_contents) LIKE ? AND visible_in_library = ?", "%#{search_term}%", true)
    else
      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
    end

    # Calculate style frequencies
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

    # Initialize ImageOptim with explicit lossy compression settings
    image_optim = ImageOptim.new(
      pngout: false,
      svgo: false,
      pngcrush: false,
      advpng: false,
      oxipng: false,
      jhead: false,
      jpegoptim: {max_quality: 55},
      pngquant: {quality: 55..65}
    )

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
    optimized_image_path = image_optim.optimize_image!(temp_file_path)
    file_path_to_upload = optimized_image_path ? optimized_image_path.to_path : temp_file_path

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

end
