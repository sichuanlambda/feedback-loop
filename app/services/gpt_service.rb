require 'base64'
require 'httparty'

class GptService
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  def initialize(content_type = 'application/json')
    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    raise "API key not found" if api_key.nil?

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
    response.code == 200 ? parse_response(response) : nil
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
            { type: "text", text: "Can you rate my dog in the style of the rate my dog account? ..." },
            { type: "image_url", image_url: { url: image_url } }
          ]
        }
      ]
    }.to_json

    response = self.class.post('/chat/completions', @options.merge(body: body))
    Rails.logger.debug "GPT Response: #{response.inspect}"
    response.code == 200 ? parse_response(response) : nil
  end

  def send_building_analysis(image_url)
    Rails.logger.debug "GptService: Received image_url for building analysis: #{image_url}"

    body = {
      model: "gpt-4-vision-preview",
      max_tokens: 1000,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Can you tell me about the architecture and design of this building? Please tell me about the different influences it has and the components of the building that relate to those influences. Then, I want learn about those different styles and influences, and instances of them in real life. Please generate response in HTML only, include headings, sub-headings, and bullet pts."
            },
            {
              type: "image_url",
              image_url: { url: image_url }
            }
          ]
        }
      ]
    }.to_json

    response = self.class.post('/chat/completions', @options.merge(body: body))
    Rails.logger.debug "GPT Response: #{response.inspect}"
    response.code == 200 ? parse_architecture_response(response) : nil
  end

  private

  def parse_response(response)
    Rails.logger.debug "GPT Raw Response: #{response.body}"
    response_data = JSON.parse(response.body)

    if response_data['choices'] && response_data['choices'].any?
      parsed_content = response_data['choices'].first['message']['content']
      Rails.logger.debug "Parsed GPT Content: #{parsed_content}"
      parsed_content
    else
      Rails.logger.debug "GPT Response: No choices present"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "JSON Parsing Error: #{e.message}"
    nil
  end

  def parse_architecture_response(response)
    Rails.logger.debug "GPT Raw Response: #{response.body}"

    response_data = JSON.parse(response.body)
    if response_data['choices'] && response_data['choices'].any?
      content = response_data['choices'].first['message']['content']
      cleaned_content = content.gsub(/\*\*/, '')
      json_content = { "analysis": cleaned_content }.to_json
      parsed_json = JSON.parse(json_content)

      Rails.logger.debug "Parsed GPT Architecture Content: #{parsed_json}"
      parsed_json
    else
      Rails.logger.debug "GPT Response: No choices present"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "JSON Parsing Error: #{e.message}"
    nil
  end
end
