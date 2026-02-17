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

    style_list = "Ancient Egyptian, Classical Greek, Classical Roman, Byzantine, Romanesque, Gothic, Renaissance, Baroque, Rococo, Neoclassical, Gothic Revival, Romanticism, Beaux-Arts, Victorian, Edwardian, Art Nouveau, Art Deco, Bauhaus, International Style, Streamline Moderne, Brutalism, Postmodernism, Deconstructivism, High-Tech, Sustainable Architecture, Parametricism, Minimalism, Expressionism, Futurism, Constructivism, Organic Architecture, Critical Regionalism, Metabolism, Neo-Futurism, Post-Structuralism, New Classical, Neo-vernacular, Neo-Byzantine, Neo-Gothic, Art & Crafts, Prairie Style, Usonian, Colonial Revival, Tudor Revival, Mediterranean Revival, Mission Revival, Spanish Colonial Revival, Pueblo Revival, Federal Style, American Foursquare, Chicago School, Italianate, Second Empire, Queen Anne, Shingle Style, Richardsonian Romanesque, Carpenter Gothic, Dutch Colonial Revival, Georgian Revival, Chateauesque, City Beautiful Movement, Modern Movement, Scandinavian Modern, Mid-Century Modern, Structuralism, Post-Industrial, High-tech, Blobitecture, De Stijl, Expressionist, Fascist, Nazi Architecture, Stalinist, Suprematism, Vorticism, Futurist, Metaphoric, New Objectivity, Rationalism, Rayonnant, Regionalism, Russian Revival, Saracen, Scottish Baronial, Sicilian Baroque, Stripped Classicism, Territorial Revival, Traditionalist School, Tropical Modernism, Vernacular, Vienna Secession, Zigzag Moderne, Anglo-Saxon, Ottonian, Carolingian, Merovingian, Norman, Salon Style, Jacobean, Elizabethan, Palladian, Adam Style, Regency, Japonism, Egyptian Revival, Mayan Revival, Indo-Saracenic"

    prompt = <<~PROMPT
      Analyze the architecture and design of this building. Return your response as a JSON object with the following structure:

      {
        "building_name": "Name of the building if recognizable, otherwise a descriptive name",
        "year_built": "Year or decade if identifiable, otherwise null",
        "architect": "Architect name if known, otherwise null",
        "overview": "A 2-3 sentence overview of the building and its architectural significance.",
        "styles": [
          {
            "name": "Style Name",
            "confidence": 85,
            "description": "A paragraph explaining how this style manifests in the building — specific elements, details, and design choices that reflect this influence.",
            "key_elements": ["Element 1", "Element 2", "Element 3"]
          }
        ],
        "notable_features": ["Feature 1", "Feature 2", "Feature 3"],
        "historical_context": "A paragraph about when and why it was built, its place in architectural history, and any significant events.",
        "fun_facts": ["Fact 1", "Fact 2"]
      }

      Rules:
      - Choose styles ONLY from this list: #{style_list}
      - Include up to 4-5 styles maximum, sorted by confidence (highest first)
      - Confidence is 0-100 representing how strongly the style is present
      - Each style should have 3-5 key_elements
      - Include 3-5 notable_features
      - Include 2-3 fun_facts
      - Return ONLY valid JSON, no other text
    PROMPT

    body = {
      model: "gpt-4o-mini",
      max_tokens: 1500,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: { url: image_url } }
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

  def analyze_style_preferences(styles_data)
    Rails.logger.debug "GptService: Analyzing style preferences: #{styles_data}"

    prompt = <<~PROMPT
      You are a witty architecture critic. Based on these architectural style preferences, create a response in this EXACT format:
      
      TITLE: [Create a clever 2-5 word title that creatively combines or plays on the top 2-3 styles. Examples: "Gothic Minimalist", "Baroque Brutalist", "Neo-Classical Rebel", "Modern Renaissance Soul"]
      
      SUMMARY: [Write ONE punchy sentence (max 20 words) that captures the essence of their aesthetic sensibility, using vivid language]
      
      The styles are:
      #{styles_data.map { |s| "#{s[:name]} (#{s[:percentage]}%)" }.join(", ")}
      
      Be creative with the title - blend the style names or create an evocative phrase. Keep it sophisticated but memorable.
    PROMPT

    body = {
      model: "gpt-4o-mini",
      max_tokens: 150,
      temperature: 0.9,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    }.to_json

    response = self.class.post('/chat/completions', @options.merge(body: body))
    Rails.logger.debug "GPT Response: #{response.inspect}"
    
    if response.code == 200
      content = parse_response(response)
      if content
        # Parse the title and summary from the response
        title_match = content.match(/TITLE:\s*(.+?)(?:\n|$)/)
        summary_match = content.match(/SUMMARY:\s*(.+?)(?:\n|$)/)
        
        # Extract the top styles for learn more links
        top_styles = styles_data.first(3).map { |s| s[:name] }
        
        {
          title: title_match ? title_match[1].strip : "Architecture Enthusiast",
          summary: summary_match ? summary_match[1].strip : content,
          top_styles: top_styles
        }
      else
        nil
      end
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
      # With response_format: json_object, content is already valid JSON
      parsed_json = JSON.parse(content)
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
