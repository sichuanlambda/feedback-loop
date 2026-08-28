module ApplicationHelper
  # Renders an achievement badge, falling back to a default badge if the
  # icon file doesn't exist so a missing asset can't 500 the page.
  def badge_image_tag(icon, **options)
    path = "badges/#{icon}"
    resolvable = begin
      resolve_asset_path(path, true).present?
    rescue
      false
    end
    path = 'badges/first-step.svg' unless resolvable
    image_tag(path, **options)
  end

  def json_ld(data)
    content_tag :script, data.to_json.html_safe, type: 'application/ld+json'
  end

  def seo_meta_tags(options = {})
    title = options[:title] || content_for(:title)
    description = options[:description] || content_for(:meta_description)
    image = options[:image] || content_for(:og_image)
    url = options[:url] || request.original_url.split('?').first
    
    tags = []
    
    # Basic meta tags
    tags << content_for(:title, title) if title.present?
    tags << content_for(:meta_description, description) if description.present?
    
    # Open Graph tags
    tags << content_for(:head, tag('meta', property: 'og:url', content: url))
    tags << content_for(:head, tag('meta', property: 'og:image', content: image)) if image.present?
    
    tags.join.html_safe
  end

  def building_structured_data(building_analysis, building_data = nil)
    return '' unless building_analysis

    name = building_data&.dig('building_name') || building_analysis.name || "Building"
    address = building_analysis.address if building_analysis.address.present? && building_analysis.address != "N/A"
    
    base_data = {
      "@context": "https://schema.org",
      "@type": "LandmarkOrHistoricalBuilding",
      "name": name,
      "url": architecture_explorer_show_url(building_analysis),
      "description": building_data&.dig('overview') || "Architectural analysis of #{name}."
    }

    if address.present? && building_analysis.latitude.present? && building_analysis.longitude.present?
      base_data[:address] = {
        "@type": "PostalAddress",
        "streetAddress": address.split(',').first,
        "addressLocality": building_analysis.city || address.split(',')[1]&.strip
      }
      
      base_data[:geo] = {
        "@type": "GeoCoordinates",
        "latitude": building_analysis.latitude,
        "longitude": building_analysis.longitude
      }
    end

    if building_analysis.image_url.present?
      base_data[:image] = building_analysis.image_url
    end

    if building_data&.dig('architect').present?
      base_data[:architect] = {
        "@type": "Person",
        "name": building_data['architect']
      }
    end

    if building_data&.dig('year_built').present?
      base_data[:dateCreated] = building_data['year_built'].to_s
    end

    if building_data&.dig('styles').present?
      base_data[:additionalProperty] = building_data['styles'].map do |style|
        {
          "@type": "PropertyValue",
          "name": "Architectural Style",
          "value": style['name']
        }
      end
    end

    json_ld(base_data)
  end

  def place_structured_data(place)
    return '' unless place

    data = {
      "@context": "https://schema.org",
      "@type": "Place",
      "name": "#{place.name} Architecture Guide",
      "description": place.meta_description || "Explore the architecture of #{place.name}. Discover the main architectural styles, notable buildings, and historical context.",
      "url": place_url(place),
      "address": {
        "@type": "PostalAddress",
        "addressLocality": place.name
      }
    }

    if place.latitude.present? && place.longitude.present?
      data[:geo] = {
        "@type": "GeoCoordinates",
        "latitude": place.latitude,
        "longitude": place.longitude
      }
    end

    if place.best_representative_image.present?
      data[:image] = place.best_representative_image
    end

    json_ld(data)
  end

  def style_structured_data(style_name, building_count)
    return '' unless style_name.present?

    data = {
      "@context": "https://schema.org",
      "@type": "CreativeWork",
      "name": "#{style_name} Architecture",
      "description": "Explore #{building_count} examples of #{style_name} architecture. Discover buildings, history, and characteristics of this architectural style.",
      "url": style_show_url(style_name: style_name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+$/, '')),
      "about": {
        "@type": "Thing",
        "name": "#{style_name} Architectural Style"
      },
      "mainEntity": {
        "@type": "ItemList",
        "numberOfItems": building_count,
        "name": "#{style_name} Buildings"
      }
    }

    json_ld(data)
  end

  def organization_structured_data
    data = {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Architecture Helper",
      "url": "https://architecturehelper.com",
      "description": "AI-powered architecture design analysis and generation tool. Explore architectural styles, analyze buildings, and discover architecture from around the world.",
      "sameAs": [
        # Add social media URLs if available
      ],
      "contactPoint": {
        "@type": "ContactPoint",
        "contactType": "Customer Service",
        "url": "https://architecturehelper.com/about"
      }
    }

    json_ld(data)
  end
end
