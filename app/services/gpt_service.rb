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
      model: "gpt-4o-mini",
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
      model: "gpt-4o-mini",
      max_tokens: 1000,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Can you tell me about the architecture and design of this building? Please tell me about the different influences it has and the components of the building that relate to those influences. Then, I want learn about those different styles and influences, and instances of them in real life. Please generate response in HTML only, feel free to use headings, sub-headings, and bullet pts. Don't include extra intro or outtro information, and please make the styles and influences H3s. Please include the 'confidence score' associated with each style as a 0-100% along with it's title like this: <style/influence title:> 87%. Can you also make all of the %s a cooler styling with css? It should be bolded and this shade of blue 0056b3. For the styles and influences, please only choose from the following list: Ancient Egyptian
              Classical Greek
              Classical Roman
              Byzantine
              Romanesque
              Gothic
              Renaissance
              Baroque
              Rococo
              Neoclassical
              Gothic Revival
              Romanticism
              Beaux-Arts
              Victorian
              Edwardian
              Art Nouveau
              Art Deco
              Bauhaus
              International Style
              Streamline Moderne
              Brutalism
              Postmodernism
              Deconstructivism
              High-Tech
              Sustainable Architecture
              Parametricism
              Minimalism
              Expressionism
              Futurism
              Constructivism
              Organic Architecture
              Critical Regionalism
              Metabolism
              Neo-Futurism
              Post-Structuralism
              New Classical
              Neo-vernacular
              Neo-Byzantine
              Neo-Gothic
              Art & Crafts
              Prairie Style
              Usonian
              Colonial Revival
              Tudor Revival
              Mediterranean Revival
              Mission Revival
              Spanish Colonial Revival
              Pueblo Revival
              Federal Style
              American Foursquare
              Chicago School
              Italianate
              Second Empire
              Queen Anne
              Shingle Style
              Richardsonian Romanesque
              Carpenter Gothic
              Dutch Colonial Revival
              Georgian Revival
              Chateauesque
              City Beautiful Movement
              Modern Movement
              Scandinavian Modern
              Mid-Century Modern
              Structuralism
              Post-Industrial
              High-tech
              Blobitecture
              De Stijl
              Expressionist
              Fascist
              Nazi Architecture
              Stalinist
              Suprematism
              Vorticism
              Futurist
              Metaphoric
              New Objectivity
              Rationalism
              Rayonnant
              Regionalism
              Russian Revival
              Saracen
              Scottish Baronial
              Sicilian Baroque
              Stripped Classicism
              Territorial Revival
              Traditionalist School
              Tropical Modernism
              Vernacular
              Vienna Secession
              Zigzag Moderne
              Anglo-Saxon
              Ottonian
              Carolingian
              Merovingian
              Norman
              Salon Style
              Jacobean
              Elizabethan
              Palladian
              Adam Style
              Regency
              Japonism
              Egyptian Revival
              Mayan Revival
              Indo-Saracenic"
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

  def send_development_estimation(image_url, address, custom_prompt, analysis_mode = 'report')
    base_prompt = case analysis_mode
    when 'report'
      "You are a real estate development expert. Based on this satellite image, please provide a detailed analysis in HTML format that covers the following:\n\n"
    when 'metrics'
      "Based on this satellite image, provide only the numerical answer or metric. No explanation or context needed. Just the number or percentage. For example, if asked about tree count, respond with just '42' or if asked about parking coverage respond with just '35%'. Here's what to analyze:\n\n"
    end

    augmented_prompt = base_prompt + custom_prompt

    Rails.logger.debug "Sending augmented prompt: #{augmented_prompt}"

    body = {
      model: "gpt-4o-mini",
      max_tokens: 1000,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: augmented_prompt
            },
            {
              type: "image_url",
              image_url: { url: image_url }
            }
          ]
        }
      ]
    }

    response = self.class.post('/chat/completions', @options.merge(body: body.to_json))
    Rails.logger.debug "GPT Response: #{response.body}"

    if response.code == 200
      parsed_response = parse_development_response(response)
      Rails.logger.debug "Parsed Response: #{parsed_response}"
      parsed_response
    else
      Rails.logger.error "GPT Error: #{response.code} - #{response.body}"
      nil
    end
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

  def parse_development_response(response)
    parsed = JSON.parse(response.body)
    Rails.logger.debug "Parsing response: #{parsed}"  # Debug log

    {
      "analysis" => parsed.dig("choices", 0, "message", "content")
    }
  rescue => e
    Rails.logger.error "Parse error: #{e.message}"
    nil
  end
end
