require 'httparty'

class DesignsController < ApplicationController
  before_action :set_gpt_api_options

  def submit
    Rails.logger.debug "Params: #{params.inspect}"
    user_selections = params[:user_selections]

    prompt = generate_prompt(user_selections)
    gpt_response = send_image_generation_request(prompt)

    @image_url = extract_image_url_from_gpt_response(gpt_response)
    Rails.logger.debug "Image URL: #{@image_url}"

    # Render the show_image view directly with @image_url
    render :show_image
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

  def generate_prompt(user_selections)
    "Generate an image of a building design that that draws inspiration from the following features: #{user_selections.join(", ")}."
  end

  def send_image_generation_request(prompt)
    Rails.logger.debug "GPT Response: #{response.body}"
    response.code == 200 ? JSON.parse(response.body) : nil

    body = {
      prompt: prompt,
      n: 1,  # Number of images to generate
      size: "1024x1024"  # Size of the generated images
    }.to_json

    response = HTTParty.post(
      'https://api.openai.com/v1/images/generations',
      body: body,
      headers: @gpt_api_options[:headers]
    )

    response.code == 200 ? JSON.parse(response.body) : nil
  end

  def extract_image_url_from_gpt_response(response)
    response["data"].first["url"] if response && response["data"]
  end

  def show_image
    @image_url = session[:image_url]
    Rails.logger.debug "Image URL retrieved from session: #{@image_url}"
  end
end
