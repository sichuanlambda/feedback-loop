require 'aws-sdk-s3'
require 'net/http'
require 'json'
require 'nokogiri'

class ArchitectureExplorerController < ApplicationController
  before_action :authenticate_user!, except: [:building_library]
  before_action :set_custom_nav

  def new
    # Renders the form for uploading an image
  end


  def create
    Rails.logger.debug "Processing the uploaded image..."
    Rails.logger.debug "Form submission received with params: #{params.inspect}"

    # Existing logic for handling directly uploaded images
    uploaded_image = params[:image]
    image_url = nil

    if uploaded_image.present?
      # Logic to handle directly uploaded image remains unchanged
      image_url = upload_image_to_s3(uploaded_image)
    elsif params[:street_view_url].present?
      # If there's no direct upload but a street view URL is present, fetch and process the street view image
      uploaded_image = fetch_street_view_image(params[:street_view_url])
      image_url = upload_image_to_s3(uploaded_image) if uploaded_image
    end

    if uploaded_image.blank?
      redirect_to root_path, alert: "No image uploaded or address provided"
      return
    end

    # Assuming process_building_image can handle both direct uploads and fetched images
    analysis_result = process_building_image(uploaded_image)

    # The rest of the method remains the same, using image_url which is now set for both direct and fetched images
    if analysis_result && analysis_result[:html_content].present?
      h3_contents = extract_h3s(analysis_result[:html_content]) # Extract H3 contents here

      new_analysis = BuildingAnalysis.create(
        html_content: analysis_result[:html_content],
        user: current_user, # Assuming you have a method to get the current user
        image_url: image_url, # This is now set for both direct uploads and fetched images
        h3_contents: h3_contents.to_json, # Save the extracted H3 contents
        visible_in_library: true, # Set default visibility in library to true
        address: params[:address].presence || "N/A" # Set address if provided
      )

      if new_analysis.persisted?
        Rails.logger.debug "New analysis created successfully with ID: #{new_analysis.id}"
        redirect_to architecture_explorer_show_path(id: new_analysis.id)
      else
        Rails.logger.debug "Failed to save new analysis. Errors: #{new_analysis.errors.full_messages.join(", ")}"
        redirect_to root_path, alert: "Analysis failed: #{new_analysis.errors.full_messages.join(", ")}"
      end
    else
      redirect_to root_path, alert: "Analysis failed"
    end
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

    # Renders the 'architecture_explorer/building_library' view
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
    render :index
  end

  def by_location
    @location_name = params[:location_name].downcase
    @analyzed_buildings = BuildingAnalysis.where("LOWER(address) LIKE ?", "%#{@location_name}%")

    # Extracting styles from h3_contents
    all_styles = []
    @analyzed_buildings.each do |building|
      styles = JSON.parse(building.h3_contents || '[]')
      all_styles.concat(styles)
    end

    # Calculating the frequency of each style
    @style_frequency = all_styles.each_with_object(Hash.new(0)) do |style, counts|
      counts[style] += 1
    end

    # Counting unique styles
    @unique_style_count = @style_frequency.keys.length

    # Counting the total number of buildings analyzed for Denver
    @buildings_submitted_count = @analyzed_buildings.count

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

    # Determine the file name
    file_name = if uploaded_file.respond_to?(:original_filename)
                  uploaded_file.original_filename
                else
                  # Generate a file name for the fetched image
                  "fetched_street_view_#{Time.now.to_i}.jpg"
                end

    obj = s3.bucket('architecture-explorer').object("uploads/#{file_name}")
    obj.upload_file(uploaded_file.respond_to?(:path) ? uploaded_file.path : uploaded_file)

    obj.public_url
  rescue => e
    Rails.logger.error "S3 Upload Failed: #{e.message}"
    nil
  end

  def set_custom_nav
    @custom_nav = true
  end

end
