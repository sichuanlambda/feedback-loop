require 'httparty'
require 'open-uri'
require 'aws-sdk-s3'

class DesignsController < ApplicationController
  before_action :authenticate_user!, except: [:style_finder, :submit]
  before_action :set_gpt_api_options
  before_action :set_custom_nav


  def style_finder
    track_event('design_style_finder')
    # Your existing style finder logic (if any)
  end
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
    
    track_event('design_submit', { 
      architecture_type: step1_selection,
      total_selections: all_selections.length,
      image_style: image_style
    })

    # Generate the prompt including the image style
    prompt = generate_prompt(step1_selection, all_selections, image_style)

    # Send the request to the image generation API
    gpt_response = send_image_generation_request(prompt)

    # gpt-image-1 returns the image as base64 rather than a hosted URL
    image_b64 = gpt_response && gpt_response.dig("data", 0, "b64_json")

    if image_b64.present?
      s3 = Aws::S3::Resource.new(region: 'us-east-2')
      obj = s3.bucket('architecture-generated').object("path/to/store/#{SecureRandom.uuid}.png")
      obj.put(body: Base64.decode64(image_b64), content_type: 'image/png')

      @image_url = obj.public_url
      ArchImageGen.create(image_url: @image_url)
    else
      Rails.logger.error "Image generation failed, no image data in response"
    end

    # Render the show_image view directly with @image_url
    render :show_image
  end

  # This action might be used to handle Step 1 form submission
  def step1_process
    track_event('design_step1_process', { selected_option: params[:selected_option] })
    session[:architecture_type] = params[:selected_option]
    redirect_to step2_path  # Redirect to Step 2
  end

  def step1
    track_event('design_step1_view')
    @latest_images = ArchImageGen.order(created_at: :desc).limit(5)
    @building_library = BuildingAnalysis.where(visible_in_library: true).order(created_at: :desc).limit(5)
    Rails.logger.debug "Latest Images: #{@latest_images}"
  end

  def user_creations
    track_event('design_user_creations')
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
    body = {
      model: 'gpt-image-1',
      prompt: prompt,
      n: 1,  # Number of images to generate
      size: "1024x1024"  # Size of the generated images
    }.to_json

    response = HTTParty.post(
      'https://api.openai.com/v1/images/generations',
      body: body,
      headers: @gpt_api_options[:headers],
      timeout: 300  # image generation can take a couple of minutes
    )

    unless response.code == 200
      Rails.logger.error "Image generation API error (HTTP #{response.code}): #{response.body}"
      return nil
    end

    JSON.parse(response.body)
  end

  def show_image
    @image_url = session[:image_url]
    Rails.logger.debug "Image URL retrieved from session: #{@image_url}"
  end

  def set_custom_nav
    @custom_nav = true
  end
end
