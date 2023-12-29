require 'aws-sdk-s3'
require 'net/http'
require 'json'

class ArchitectureExplorerController < ApplicationController
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
    Rails.logger.debug "Analysis result: #{analysis_result.inspect}"

    if analysis_result && analysis_result[:html_content].present?
      new_analysis = BuildingAnalysis.create(html_content: analysis_result[:html_content])
      redirect_to architecture_explorer_show_path(id: new_analysis.id)
    else
      redirect_to root_path, alert: "Analysis failed"
    end
  end

  def show
    @building_analysis = BuildingAnalysis.find_by(id: params[:id])

    if @building_analysis
      @html_content = @building_analysis.html_content
    else
      redirect_to root_path, alert: "Analysis not found"
    end
  end

  private

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
end
