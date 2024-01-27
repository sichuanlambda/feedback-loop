require 'httparty'
require 'open-uri'
require 'aws-sdk-s3'

class DesignsController < ApplicationController
  before_action :set_gpt_api_options
  before_action :set_custom_nav

  # This action handles the final submission and API call
  def submit
    Rails.logger.debug "Params: #{params.inspect}"

    # Retrieve selections from sessions and parameters
    step1_selection = session[:architecture_type] || 'default architecture type'
    step2_selections = session[:step2_selections] || []
    step3_selections = params[:user_selections] || []

    # Combine selections from step 2 and step 3
    all_selections = step2_selections + step3_selections

    # Extract the image style from the parameters
    image_style = params[:image_style] || 'photo-realistic style'

    # Generate the prompt including the image style
    prompt = generate_prompt(step1_selection, all_selections, image_style)

    # Send the request to the image generation API
    gpt_response = send_image_generation_request(prompt)

    # Extract the image URL from the response
    @image_url = extract_image_url_from_gpt_response(gpt_response)
    Rails.logger.debug "Image URL: #{@image_url}"

    # Save the image URL in the ArchImageGen model
    if @image_url.present?
      file = URI.open(@image_url)
      s3 = Aws::S3::Resource.new(region: 'us-east-2')
      obj = s3.bucket('architecture-generated').object("path/to/store/#{SecureRandom.uuid}.jpg")
      obj.upload_file(file)  # Removed the acl:'public-read'

      # Save the S3 URL instead of the GPT URL
      ArchImageGen.create(image_url: obj.public_url)
    else
      Rails.logger.debug "No image URL to save"
    end

    # Render the show_image view directly with @image_url
    render :show_image
  end

  # This action might be used to handle Step 1 form submission
  def step1_process
    session[:architecture_type] = params[:selected_option]
    redirect_to step2_path  # Redirect to Step 2
  end

  def step1
    @latest_images = ArchImageGen.order(created_at: :desc).limit(5)
    @building_library = BuildingAnalysis.where(visible_in_library: true).order(created_at: :desc).limit(5)
    Rails.logger.debug "Latest Images: #{@latest_images}"
  end

  def user_creations
    @submissions = ArchImageGen.order(created_at: :desc).limit(24)
  end

  private

  def set_gpt_api_options
    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    raise "API key not found" if api_key.nil?

    @gpt_api_options = {
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      }
    }
  end

  # This method generates the prompt for the DALL-E API
  def generate_prompt(step1_selection, all_selections, image_style)
    prompt = "Generate an image of a #{step1_selection} with style and inspiration drawing from #{all_selections.join(", ")}."
    prompt += " Please generate the image as a #{image_style}." unless image_style.blank?
    prompt
  end

  def send_image_generation_request(prompt)
    Rails.logger.debug "GPT Response: #{response.body}"
    response.code == 200 ? JSON.parse(response.body) : nil

    body = {
      model: 'dall-e-3',
      prompt: prompt,
      n: 1,  # Number of images to generate
      size: "1024x1024"  # Size of the generated images
    }.to_json

    response = HTTParty.post(
      'https://api.openai.com/v1/images/generations',
      body: body,
      headers: @gpt_api_options[:headers]
    )
    Rails.logger.debug "API Response: #{response.body}"  # Log the entire response

    response.code == 200 ? JSON.parse(response.body) : nil
  end

  def extract_image_url_from_gpt_response(response)
    response["data"].first["url"] if response && response["data"]
  end

  def show_image
    @image_url = session[:image_url]
    Rails.logger.debug "Image URL retrieved from session: #{@image_url}"
  end

  def set_custom_nav
    @custom_nav = true
  end
end
