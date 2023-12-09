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

    if response.code == 200
      parse_response(response)
    else
      nil # or handle error accordingly
    end
  end

  def send_image(image)
    encoded_image = Base64.encode64(image.read)

    body = {
      model: "gpt-4-vision-preview",
      inputs: {
        "image": encoded_image,
        "prompt": "Can you rate my dog in the style of the rate my dog account? It should be funny, playful, and kind. The dog should get a score of 10/10 or even higher (12/10).         Here are some examples from the account:
        This is Teddy. He loves when it starts to get cold out. Because that means it’s sweater weather. And he happens to be a giant walking sweater. 14/10
        This is Zeppole. He thought he caught a big fish at first. Then he realized he was the good catch all along. 13/10
        This is Cobra. His humans took him to see Christmas lights. Didn't understand what people meant by the magic of Christmas until now. 13/10"
      }
    }.to_json

    response = self.class.post('/image/completions', @options.merge(body: body)) # Update endpoint if needed

    if response.code == 200
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
