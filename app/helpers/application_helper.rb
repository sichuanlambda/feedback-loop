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

  # FAQPage JSON-LD for an array of { question:, answer: } (string or symbol
  # keys). Answers are stripped to plain text. Google no longer shows FAQ rich
  # results for most sites, so the visible section (shared/faq_section) is
  # what carries the SEO weight; this markup is cheap and keeps the two in sync.
  def faq_structured_data(faqs)
    items = normalize_faqs(faqs)
    return '' if items.empty?

    json_ld(
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": items.map do |f|
        {
          "@type": "Question",
          "name": f[:question],
          "acceptedAnswer": { "@type": "Answer", "text": strip_tags(f[:answer]).squish }
        }
      end
    )
  end

  def normalize_faqs(faqs)
    Array(faqs).filter_map do |f|
      next unless f.is_a?(Hash)
      f = f.with_indifferent_access
      next if f[:question].blank? || f[:answer].blank?
      { question: f[:question].to_s.strip, answer: f[:answer].to_s.strip }
    end
  end

  # ---- Data-driven FAQ fallbacks. Only facts the page already shows, so a
  # page with no generated FAQ still gets an honest Q&A block. ----

  def place_default_faqs(place, top_styles, building_count)
    faqs = []
    if top_styles.present?
      lead, *rest = top_styles.first(3).map(&:first)
      answer = "#{lead} is the most common style among the #{building_count} #{place.name} buildings documented on Architecture Helper"
      answer += rest.any? ? ", followed by #{rest.to_sentence}." : "."
      faqs << { question: "What architectural style is #{place.name} known for?", answer: answer }
    end
    if building_count.to_i > 0
      faqs << { question: "How many buildings in #{place.name} have been analyzed?",
                answer: "#{building_count} buildings in #{place.name} have been photographed and analyzed for architectural style, each with its own page describing the style, notable features and historical context." }
    end
    faqs << { question: "Can I explore #{place.name}'s architecture on a map?",
              answer: "Yes. The interactive map on this page plots every documented building in #{place.name}, and the tour builder lets you pick buildings and generate a walking route between them." }
    faqs
  end

  def style_default_faqs(style_name, info, cities, related_styles)
    info = (info || {}).with_indifferent_access
    faqs = []
    faqs << { question: "What is #{style_name} architecture?", answer: info[:intro] } if info[:intro].present?
    if info[:era].present?
      answer = "#{style_name} architecture flourished #{info[:era]}"
      answer += info[:origin].present? ? ", originating in #{info[:origin]}." : "."
      faqs << { question: "When was #{style_name} architecture popular?", answer: answer }
    end
    if info[:characteristics].present?
      faqs << { question: "What are the key characteristics of #{style_name} architecture?",
                answer: "Typical #{style_name} features include: #{Array(info[:characteristics]).first(5).map { |c| c.to_s.sub(/\.\z/, '') }.to_sentence.downcase}." }
    end
    if cities.present?
      names = cities.first(5).map(&:first)
      answer = "In the Architecture Helper library, #{style_name} buildings are most concentrated in #{names.to_sentence}."
      if info[:famous_examples].present?
        answer += " Famous examples worldwide include #{Array(info[:famous_examples]).first(3).map { |e| "#{e[:name]} (#{e[:city]})" }.to_sentence}."
      end
      faqs << { question: "Where can I see #{style_name} architecture?", answer: answer }
    end
    if related_styles.present?
      faqs << { question: "Which styles are related to #{style_name}?",
                answer: "Buildings analyzed as #{style_name} most often also show #{related_styles.first(4).map(&:first).to_sentence}, so those are the styles worth comparing it against." }
    end
    faqs
  end

  def style_city_default_faqs(style_name, city_name, buildings, related_styles, other_cities)
    faqs = []
    count = buildings.size
    faqs << { question: "How many #{style_name} buildings are there in #{city_name}?",
              answer: "Architecture Helper has documented #{count} #{style_name} #{'building'.pluralize(count)} in #{city_name}, each analyzed from a photograph to identify the style, its key elements and historical context." }
    examples = buildings.first(4).map { |b| b.display_name || b.display_address.to_s.split(',').first }.reject(&:blank?)
    if examples.any?
      faqs << { question: "What are notable examples of #{style_name} architecture in #{city_name}?",
                answer: "Documented examples include #{examples.to_sentence}. Each has its own analysis page with photos, the identified style elements and background on the building." }
    end
    if related_styles.present?
      faqs << { question: "What other architectural styles are common in #{city_name}?",
                answer: "Alongside #{style_name}, buildings in #{city_name} are most often identified as #{related_styles.first(4).map(&:first).to_sentence}." }
    end
    if other_cities.present?
      faqs << { question: "Where else can I find #{style_name} architecture?",
                answer: "Other cities with documented #{style_name} buildings include #{other_cities.first(5).map(&:first).to_sentence}." }
    end
    faqs
  end

  def building_default_faqs(building, data)
    return [] unless data.is_a?(Hash)
    name = data['building_name'].presence || building.display_name || 'this building'
    faqs = []
    styles = Array(data['styles']).select { |s| s['name'].present? }
    if styles.any?
      lead = styles.first
      answer = "#{name} is primarily #{lead['name']} architecture"
      answer += " (#{lead['confidence']}% confidence)" if lead['confidence'].present?
      others = styles.drop(1).map { |s| s['name'] }
      answer += others.any? ? ", with elements of #{others.to_sentence}." : "."
      answer += " #{lead['description']}" if lead['description'].present?
      faqs << { question: "What architectural style is #{name}?", answer: answer }
    end
    if data['year_built'].present?
      faqs << { question: "When was #{name} built?", answer: "#{name} dates from #{data['year_built']}." }
    end
    if data['architect'].present?
      faqs << { question: "Who designed #{name}?", answer: "#{name} was designed by #{data['architect']}." }
    end
    if building.display_address.present?
      answer = "#{name} is located at #{building.display_address}"
      answer += building.city.present? && !building.display_address.include?(building.city) ? " in #{building.city}." : "."
      faqs << { question: "Where is #{name} located?", answer: answer }
    end
    if data['notable_features'].present?
      faqs << { question: "What are the notable features of #{name}?",
                answer: "Notable features include #{Array(data['notable_features']).first(5).map { |f| f.to_s.sub(/\.\z/, '') }.to_sentence.downcase}." }
    end
    faqs.size >= 2 ? faqs : []
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
