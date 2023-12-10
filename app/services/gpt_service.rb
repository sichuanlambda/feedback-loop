require 'httparty'
require 'json'
require 'mini_magick'
require 'base64'

class GptService
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  def initialize(content_type = 'application/json')
    @api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    raise "API key not found" if @api_key.nil?

    @options = {
      headers: {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => content_type
      }
    }
  end

  def send_image(image_file)
    # Save the uploaded file to a temporary path
    temp_path = Rails.root.join('tmp', image_file.original_filename)
    File.open(temp_path, 'wb') do |file|
      file.write(image_file.read)
    end

    # Resize the image and prepare a temporary path for the resized image
    resized_image_path = Rails.root.join('tmp', "resized_#{image_file.original_filename}")
    resize_image(temp_path, resized_image_path.to_s)

    # Convert the resized image to base64
    encoded_image = Base64.encode64(File.open(resized_image_path, 'rb').read)

    body = {
      model: "gpt-4-vision-preview",
      messages: [
        {
          "role": "system",
          "content": "Can you rate my dog in the style of the rate my dog account? It should be funny, playful, and kind. The dog should get a score of 10/10 or even higher (12/10). Here are some examples from the account:
          This is Teddy. He loves when it starts to get cold out. Because that means it’s sweater weather. And he happens to be a giant walking sweater. 14/10
          This is Zeppole. He thought he caught a big fish at first. Then he realized he was the good catch all along. 13/10
          This is Cobra. His humans took him to see Christmas lights. Didn't understand what people meant by the magic of Christmas until now. 13/10"
        },
        {
          "role": "user",
          "content": encoded_image
        }
      ]
    }.to_json

    response = self.class.post('/chat/completions', body: body, headers: @options[:headers])

    if response.code == 200
      parse_response(response)
    else
      Rails.logger.error "Error with GPT image response: Status code #{response.code}, body #{response.body}"
      nil
    end
  ensure
    # Clean up the temporary files
    File.delete(temp_path) if File.exist?(temp_path)
    File.delete(resized_image_path) if File.exist?(resized_image_path)
  end

  private

  def resize_image(image_path, output_path, max_width: 800, max_height: 800)
    image = MiniMagick::Image.open(image_path)
    image.resize "#{max_width}x#{max_height}"
    image.write output_path
  end

  def parse_response(response)
    response_data = JSON.parse(response.body)
    if response_data['choices'] && response_data['choices'].any?
      response_data['choices'].first['message']['content']
    else
      nil
    end
  rescue JSON::ParserError
    nil
  end
end
