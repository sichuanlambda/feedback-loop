require 'base64'
require 'httparty'

class GptService
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  def initialize(content_type = 'application/json')
    # Retrieve the API key from environment variables or Rails credentials
    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    raise "API key not found" if api_key.nil?

    # Set the common options, including the authorization header
    @options = {
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => content_type
      }
    }
  end

  def send_prompt(prompt)
    body = {
      model: "gpt-3.5-turbo-1106",
      messages: [
        { "role": "user", "content": prompt }
      ]
    }.to_json

    response = self.class.post('/chat/completions', @options.merge(body: body))

    if response.code == 200
      parse_response(response)
    else
      nil # or handle error accordingly
    end
  end

  def send_image_url(image_url)
    Rails.logger.debug "GptService: Received image_url: #{image_url}"
    max_tokens = 1000
    body = {
      model: "gpt-4-vision-preview",
      max_tokens: max_tokens,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: "Can you rate my dog in the style of the rate my dog account? It should be funny, playful, and kind. Here are some examples from the account:
            This is Teddy. He loves when it starts to get cold out. Because that means it’s sweater weather. And he happens to be a giant walking sweater. 14/10
            This is Cobra. His humans took him to see Christmas lights. Didn't understand what people meant by the magic of Christmas until now. 13/10
            This is Zeppole. He thought he caught a big fish at first. Then he realized he was the good catch all along. 13/10
            Add a random score of 11/10, 12/10, 13/10, or 14/10 at the end" },
            { type: "image_url", image_url: { url: image_url } }
          ]
        }
      ]
    }.to_json
    response = self.class.post('/chat/completions', @options.merge(body: body))
    Rails.logger.debug "GPT Response: #{response.inspect}"

    if response.code == 200
      parse_response(response)
    else
      nil # or handle error accordingly
    end
  end

  private

  def parse_response(response)
    # Log the raw response body
    Rails.logger.debug "GPT Raw Response: #{response.body}"

    response_data = JSON.parse(response.body)
    if response_data['choices'] && response_data['choices'].any?
      # Log the parsed response content
      parsed_content = response_data['choices'].first['message']['content']
      Rails.logger.debug "Parsed GPT Content: #{parsed_content}"
      parsed_content
    else
      # Log if no choices are present
      Rails.logger.debug "GPT Response: No choices present"
      nil
    end
  rescue JSON::ParserError => e
    # Log JSON parsing errors
    Rails.logger.error "JSON Parsing Error: #{e.message}"
    nil
  end
end
