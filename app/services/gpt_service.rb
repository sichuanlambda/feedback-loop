require 'httparty'

class GptService
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  def initialize
    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]

    @options = {
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
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

    # Check if the response code is 200 (OK)
    if response.code == 200
      # Parse the response body and extract the content
      parse_response(response)
    else
      nil # or handle error accordingly
    end
  end

  private

  def parse_response(response)
    response_data = JSON.parse(response.body)
    if response_data['choices'] && response_data['choices'].any?
      response_data['choices'].first['message']['content']
    else
      nil # Handle case where 'choices' is not present or empty
    end
  rescue JSON::ParserError
    nil # Handle JSON parsing error
  end
end
