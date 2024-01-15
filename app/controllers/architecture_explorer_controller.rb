require 'aws-sdk-s3'
require 'net/http'
require 'json'
require 'nokogiri'

class ArchitectureExplorerController < ApplicationController
  before_action :authenticate_user!
  before_action :set_custom_nav

  def new
    # Renders the form for uploading an image
  end

  def create
    Rails.logger.debug "Processing the uploaded image..."
    uploaded_image = params[:image]

    if uploaded_image.blank?
      redirect_to root_path, alert: "No image uploaded"
      return
    end

    analysis_result = process_building_image(uploaded_image)
    image_url = upload_image_to_s3(uploaded_image) # Get the image URL

    Rails.logger.debug "Analysis result: #{analysis_result.inspect}"

    if analysis_result && analysis_result[:html_content].present?
      h3_contents = extract_h3s(analysis_result[:html_content]) # Extract H3 contents here

      new_analysis = BuildingAnalysis.create(
        html_content: analysis_result[:html_content],
        user: current_user, # Assuming you have a method to get the current user
        image_url: image_url, # Save the image URL
        h3_contents: h3_contents, # Save the extracted H3 contents
        visible_in_library: true, # Set default visibility in library to true
        address: params[:address].presence || "N/A" # Set default to "N/A" if address is not provided
      )
      redirect_to architecture_explorer_show_path(id: new_analysis.id)
    else
      redirect_to root_path, alert: "Analysis failed"
    end
  end

  def show
    @building_analysis = BuildingAnalysis.find_by(id: params[:id])
    @is_shared = @building_analysis.visible_in_library

    if @building_analysis
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
    if params[:search].present?
      search_term = params[:search].downcase
      # Fetches records that contain the search term in `h3_contents` and are visible in the library
      @analyzed_buildings = BuildingAnalysis.where("LOWER(h3_contents) LIKE ? AND visible_in_library = ?", "%#{search_term}%", true)
    else
      # Fetches all records that are visible in the library when there is no search term
      @analyzed_buildings = BuildingAnalysis.where(visible_in_library: true)
    end

    # Orders the results by creation date in descending order
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
  private

  def building_analysis_params
    params.require(:building_analysis).permit(:address)
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

  def remove_code_block_markers(html_content)
    html_content.gsub(/^```html\n/, "").gsub(/\n```$/, "")
  end

  def upload_image_to_s3(uploaded_file)
    return nil if uploaded_file.blank?
    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    obj = s3.bucket('architecture-explorer').object("uploads/#{uploaded_file.original_filename}")
    obj.upload_file(uploaded_file.tempfile.path)
    obj.public_url
  rescue => e
    Rails.logger.error "S3 Upload Failed: #{e.message}"
    nil
  end

  def set_custom_nav
    @custom_nav = true
  end

end
