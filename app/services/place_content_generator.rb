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
      
      # Update place with generation timestamp
      @place.update(content_generated_at: Time.current)
      
      Rails.logger.info "Successfully generated content and images for #{@place.name}"
      true
    rescue => e
      Rails.logger.error "Failed to generate content for #{@place.name}: #{e.message}"
      false
    end
  end

  private

  def generate_content
    return if @place.has_content?
    
    # Get architectural styles from existing building analyses
    styles_summary = @place.architectural_styles_summary
    top_styles = styles_summary.first(3).map(&:first)
    
    # Create content using GPT or similar AI service
    content_prompt = build_content_prompt(top_styles)
    generated_content = generate_content_with_ai(content_prompt)
    
    if generated_content.present?
      @place.update(content: generated_content)
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

  def build_content_prompt(styles)
    styles_text = styles.any? ? styles.join(', ') : 'various architectural styles'
    
    "Write a comprehensive but concise HTML article about the architecture of #{@place.name}. " \
    "Focus on the main architectural styles found in the area: #{styles_text}. " \
    "Include sections about historical context, notable buildings, and contemporary developments. " \
    "Use proper HTML tags (h2, h3, p) and keep it engaging for architecture enthusiasts. " \
    "Length should be 300-500 words."
  end

  def generate_content_with_ai(prompt)
    # This would integrate with your existing GPT service
    # For now, return nil to trigger fallback
    nil
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
      .where.not(image_url: [nil, ''])
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