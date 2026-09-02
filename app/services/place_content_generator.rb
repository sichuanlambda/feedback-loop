class PlaceContentGenerator
  include HTTParty
  
  def initialize(place)
    @place = place
  end

  def generate_content_and_images
    Rails.logger.info "Generating content and images for #{@place.name}"
    
    begin
      # Generate content first
      generate_content unless @place.has_content?
      
      # Generate SEO and meta information
      generate_seo_meta unless @place.meta_title.present? && @place.meta_description.present?
      
      # Generate hero image
      generate_hero_image unless @place.has_hero_image?

      # FAQ (rendered on the page + FAQPage schema)
      generate_faq if @place.faq.blank?
      
      # Update place with generation timestamp
      @place.update(content_generated_at: Time.current)
      
      Rails.logger.info "Successfully generated content and images for #{@place.name}"
      true
    rescue => e
      Rails.logger.error "Failed to generate content for #{@place.name}: #{e.message}"
      false
    end
  end

  # FAQ only, for places that already have an article (backfill). Public so
  # the rake task can call it directly.
  def generate_faq
    return @place.faq if @place.faq.present?

    top_styles = @place.architectural_styles_summary.first(4)
    result = GptService.new.chat_json(faq_prompt(top_styles), max_tokens: 1200)
    faq = clean_faq(result && result['faq'])
    @place.update(faq: faq) if faq.any?
    faq
  end

  private

  def generate_content
    return if @place.has_content?
    
    # Get architectural styles from existing building analyses
    styles_summary = @place.architectural_styles_summary
    top_styles = styles_summary.first(3).map(&:first)
    
    generated = generate_content_with_ai(top_styles)

    if generated && generated[:content].present?
      @place.update(content: generated[:content], faq: generated[:faq].presence || @place.faq)
    else
      # Fallback to basic content
      @place.update(content: generate_fallback_content(top_styles))
    end
  end


  def generate_seo_meta
    return if @place.meta_title.present? && @place.meta_description.present?
    
    # Get building count and styles for SEO
    building_count = @place.building_analyses_in_place.count
    styles_summary = @place.architectural_styles_summary
    top_styles = styles_summary.first(3).map(&:first)
    
    # Generate meta title
    meta_title = generate_meta_title(building_count, top_styles)
    
    # Generate meta description
    meta_description = generate_meta_description(building_count, top_styles)
    
    @place.update(
      meta_title: meta_title,
      meta_description: meta_description
    )
  end

  def generate_meta_title(building_count, top_styles)
    if top_styles.any?
      style_text = top_styles.first(2).join(' & ')
      "#{@place.name} Architecture Guide - #{style_text} Styles"
    else
      "#{@place.name} Architecture Guide - Discover Local Buildings"
    end
  end

  def generate_meta_description(building_count, top_styles)
    if top_styles.any?
      style_text = top_styles.first(3).join(', ')
      "Explore the architecture of #{@place.name}. Discover #{building_count} analyzed buildings featuring #{style_text} styles. Get insights into local architectural heritage and contemporary design."
    else
      "Explore the architecture of #{@place.name}. Discover #{building_count} analyzed buildings and learn about the city's unique architectural character, from historic landmarks to modern developments."
    end
  end

  def generate_hero_image
    return if @place.has_hero_image?
    
    # Try multiple image sources in order of preference
    image_url = try_unsplash_image || 
                try_representative_building_image || 
                generate_ai_image
    
    if image_url.present?
      @place.update(
        hero_image_url: image_url,
        image_source: determine_image_source(image_url)
      )
    end
  end

  def building_notes(limit = 24)
    @place.building_analyses_in_place.with_showable_image.order(created_at: :desc).first(limit).map do |b|
      name = b.display_name || b.display_address.to_s.split(',').first
      styles = begin
        StyleNormalizer.normalize_array(JSON.parse(b.h3_contents.to_s)).first(3)
      rescue JSON::ParserError
        []
      end
      line = "- #{name}"
      line += " (#{b.display_address})" if b.display_address.present? && b.display_address != name
      line += " [#{styles.join(', ')}]" if styles.any?
      line += " url=/architecture_explorer/#{b.id}"
      line
    end.join("\n")
  end

  def styles_note(top_styles)
    summary = @place.architectural_styles_summary
    return 'no style data yet' if summary.empty?
    summary.map { |style, count| "#{style} (#{count})" }.join(', ')
  end

  def content_prompt(top_styles)
    <<~PROMPT
      You write city architecture guides for Architecture Helper, a site that documents real buildings with AI analysis.

      Write the guide for #{@place.name}. The library currently holds #{@place.building_analyses_in_place.count} documented buildings there.
      Styles by frequency in the library: #{styles_note(top_styles)}.
      Documented buildings (name, address, styles, page url):
      #{building_notes}

      Return JSON with exactly these keys:
      {
        "content_html": "An HTML article of 900 to 1200 words using only <h2>, <h3>, <p>, <ul>, <li>, <strong>, <em> and <a> tags. Structure: an opening section with no heading (2 paragraphs); <h2>Architectural history of #{@place.name}</h2> (200 to 280 words: periods, the events and economy that shaped building, local materials and traditions); <h2>Signature styles</h2> with one <h3> per major style in the library, 90 to 140 words each, naming specific documented buildings as examples; <h2>Where to look</h2> (150 to 220 words on neighbourhoods, streets or districts and what each is known for); <h2>Notable buildings</h2> as a <ul> where each <li> names a documented building, links it with <a href=\"url\"> using the url given above, and adds one sentence on why it matters; <h2>Tips for exploring #{@place.name}'s architecture</h2> (120 to 180 words). Only link buildings from the list. Do not invent architects, dates or addresses; if you are not certain of a fact about a listed building, describe what is visible instead.",
        "faq": [ { "question": "...", "answer": "..." } ]
      }

      FAQ rules: 5 questions a visitor or a search user would actually ask about #{@place.name}'s architecture (dominant style, best areas to walk, oldest or most famous buildings, how the city's architecture compares to nearby cities, whether the notable buildings can be visited). Plain-text answers of 40 to 80 words, specific to #{@place.name}, grounded in the buildings above where possible.

      Style rules: knowledgeable and specific, written for architecture enthusiasts planning a visit. The article must be at least 900 words; if the documented list is short, spend the extra length on the city's real architectural history, districts and building traditions rather than padding. No marketing fluff, no exclamation marks, never use em dashes, and avoid stock phrases such as "rich tapestry", "vibrant", "nestled", "testament to", "boasts" and "gem".
    PROMPT
  end

  def faq_prompt(top_styles)
    summary = ActionController::Base.helpers.strip_tags(@place.content.to_s).squish.truncate(1800)
    <<~PROMPT
      Architecture Helper has a city architecture guide for #{@place.name}. Here is a summary of it:
      #{summary}

      Styles by frequency in our library for #{@place.name}: #{styles_note(top_styles)}.
      Some documented buildings:
      #{building_notes(12)}

      Return JSON: { "faq": [ { "question": "...", "answer": "..." } ] } with 5 questions a visitor or search user would actually ask about #{@place.name}'s architecture (dominant style, best areas to walk, oldest or most famous buildings, how it compares to nearby cities, whether notable buildings can be visited). Plain-text answers, 40 to 80 words each, specific to #{@place.name}, consistent with the guide. No exclamation marks, never use em dashes.
    PROMPT
  end

  # Returns { content:, faq: } or nil so generate_content can fall back.
  # City guides are the flagship long-form pages (a few dozen of them), so
  # they get the full model; the many style-in-city pages use the mini one.
  def generate_content_with_ai(top_styles)
    result = GptService.new.chat_json(content_prompt(top_styles), model: 'gpt-4o', max_tokens: 4000)
    return nil unless result && result['content_html'].to_s.strip.present?

    { content: GeneratedCopy.clean(result['content_html'].to_s.strip), faq: clean_faq(result['faq']) }
  end

  def clean_faq(raw)
    return [] unless raw.is_a?(Array)
    GeneratedCopy.clean_faq(raw.first(6))
  end

  def generate_fallback_content(styles)
    styles_text = styles.any? ? styles.join(', ') : 'diverse architectural styles'
    
    <<~HTML
      <h2>About #{@place.name} Architecture</h2>
      <p>This guide explores the architectural heritage and contemporary design of #{@place.name}. 
      From historic landmarks to modern developments, discover the diverse styles that shape the city's built environment.</p>
      
      <h3>Primary Architectural Styles</h3>
      <p>The architecture of #{@place.name} showcases #{styles_text}, reflecting the city's rich history 
      and evolving urban landscape. Each style tells a story of the periods and influences that have shaped the city.</p>
      
      <h3>Historical Context</h3>
      <p>The built environment of #{@place.name} has evolved over centuries, with each era leaving its mark 
      on the city's architectural character. From early settlements to modern urban planning, the architecture 
      reflects the social, economic, and cultural forces that have influenced the region.</p>
      
      <h3>Notable Buildings</h3>
      <p>Explore the map to discover analyzed buildings in #{@place.name}. Each building has been analyzed 
      using AI to identify its architectural characteristics and historical context, providing insights into 
      the diverse styles that define the city's skyline.</p>
      
      <h3>Contemporary Developments</h3>
      <p>Modern #{@place.name} continues to embrace innovative architectural approaches, with new developments 
      that blend contemporary design with respect for the city's architectural heritage. These projects 
      demonstrate how the city is evolving while maintaining its unique character.</p>
    HTML
  end

  def try_unsplash_image
    return nil unless Rails.application.credentials.unsplash&.dig(:access_key)
    
    query = "#{@place.name} architecture buildings"
    url = "https://api.unsplash.com/search/photos"
    
    response = HTTParty.get(url, query: {
      query: query,
      orientation: 'landscape',
      per_page: 1
    }, headers: {
      'Authorization' => "Client-ID #{Rails.application.credentials.unsplash[:access_key]}"
    })
    
    if response.success? && response['results'].any?
      photo = response['results'].first
      photo['urls']['regular']
    end
  rescue => e
    Rails.logger.error "Unsplash API error: #{e.message}"
    nil
  end

  def try_representative_building_image
    best_building = @place.building_analyses_in_place
      .with_showable_image
      .order('RANDOM()')
      .first
    
    best_building&.image_url
  end

  def generate_ai_image
    # This would integrate with DALL-E, Stable Diffusion, or similar
    # For now, return nil
    nil
  end

  def determine_image_source(image_url)
    if image_url.include?('unsplash')
      'unsplash'
    elsif image_url.include?('architecture-explorer')
      'building_analysis'
    elsif image_url.include?('dall-e') || image_url.include?('stable-diffusion')
      'ai_generated'
    else
      'external'
    end
  end
end 