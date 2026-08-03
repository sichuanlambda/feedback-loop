module StyleNormalizer
  # Canonical style taxonomy — the SINGLE SOURCE OF TRUTH.
  # GPT prompt, normalizer, and style pages all derive from this list.
  # Ordered roughly chronologically within each era.
  CANONICAL_STYLES = {
    # Ancient & Classical
    "Ancient Egyptian"          => ["egyptian", "ancient egyptian", "egyptian revival"],
    "Classical Greek"           => ["classical greek", "greek", "hellenistic"],
    "Classical Roman"           => ["classical roman", "roman", "roman architecture"],
    "Byzantine"                 => ["byzantine", "neo-byzantine", "neo byzantine"],
    "Romanesque"                => ["romanesque", "neo-romanesque", "neoromantesque", "richardsonian romanesque"],
    "Gothic"                    => ["gothic", "gothic architecture", "neo-gothic", "neogothic", "gothic revival", "carpenter gothic", "rayonnant"],
    "Renaissance"               => ["renaissance", "neo-renaissance", "neorenaissance", "italian renaissance"],
    "Baroque"                   => ["baroque", "sicilian baroque"],
    "Rococo"                    => ["rococo"],
    "Palladian"                 => ["palladian", "adam style"],

    # Islamic & South/Southeast Asian
    "Islamic"                   => ["islamic", "islamic architecture", "moorish", "moorish revival", "moorish influence", "neo-moorish", "mudejar", "mudjar", "neo-mudejar", "andalusian", "ottoman", "persian", "saracen"],
    "Mughal"                    => ["mughal", "mughal architecture", "indo-islamic"],
    "Hindu Temple"              => ["hindu temple", "hindu temple architecture", "dravidian", "nagara"],
    "Rajasthani"                => ["rajasthani", "rajasthani architecture", "rajput", "rajput architecture"],

    # 18th-19th Century Revival & Classical
    "Neoclassical"              => ["neoclassical", "neoclassicism", "classical revival", "greek revival", "federal", "federal style", "stripped classicism", "new classical"],
    "Beaux-Arts"                => ["beaux-arts", "beaux arts", "city beautiful", "city beautiful movement", "haussmann"],
    "Victorian"                 => ["victorian", "folk victorian", "queen anne", "second empire", "edwardian", "regency", "regency architecture"],
    "Colonial Revival"          => ["colonial", "colonial revival", "dutch colonial", "dutch colonial revival", "georgian", "georgian revival", "cape cod"],
    "Tudor Revival"             => ["tudor", "tudor revival", "jacobean", "elizabethan", "scottish baronial", "norman"],
    "Italianate"                => ["italianate"],
    "Romanesque Revival"        => ["romanesque revival"],

    # Arts & Crafts / Early 20th Century
    "Arts and Crafts"           => ["arts and crafts", "arts & crafts", "art & crafts", "craftsman", "shingle style", "american foursquare"],
    "Art Nouveau"               => ["art nouveau", "vienna secession", "jugendstil", "japonism", "japonisme"],
    "Art Deco"                  => ["art deco", "zigzag moderne", "streamline moderne", "art moderne"],

    # Mission / Spanish / Mediterranean
    "Mediterranean Revival"     => ["mediterranean", "mediterranean revival", "spanish colonial", "spanish colonial revival", "spanish revival", "mission", "mission revival", "pueblo", "pueblo revival", "territorial revival"],

    # Modernism
    "Modernism"                 => [
      "modern", "modern movement", "modernism", "modernist",
      "international style", "international",
      "bauhaus", "de stijl",
      "functionalism", "functionalist",
      "constructivism", "suprematism",
      "new objectivity", "rationalism",
      "scandinavian modern",
      "tropical modernism"
    ],
    "Prairie Style"             => ["prairie style", "prairie", "usonian"],
    "Expressionism"             => ["expressionism", "expressionist", "blobitecture"],
    "Futurism"                  => ["futurism", "futurist", "neo-futurism", "neo futurism"],
    "Mid-Century Modern"        => ["mid-century modern", "mid century modern", "mcm"],

    # Brutalism & Late Modernism
    "Brutalism"                 => ["brutalism", "brutalist", "new brutalism"],
    "Structuralism"             => ["structuralism", "structural expressionism", "structuralist"],
    "Metabolism"                => ["metabolism", "metabolist"],

    # Postmodernism & Contemporary
    "Postmodernism"             => ["postmodernism", "postmodern", "post-modernism", "post modernism", "post-modern"],
    "Deconstructivism"          => ["deconstructivism", "deconstructivist", "post-structuralism"],
    "High-Tech"                 => ["high-tech", "high tech", "hightech", "hi-tech"],
    "Critical Regionalism"      => ["critical regionalism", "regionalism", "neo-vernacular", "neovernacular", "vernacular"],
    "Parametricism"             => ["parametricism", "parametric", "computational design"],
    "Contemporary"              => ["contemporary", "contemporary modern", "modern contemporary"],

    # Sustainable / Green
    "Sustainable Architecture"  => ["sustainable", "sustainable architecture", "eco-friendly", "eco friendly", "green architecture", "biophilic", "green"],

    # Organic
    "Organic Architecture"      => ["organic architecture", "organic"],

    # Minimalism
    "Minimalism"                => ["minimalism", "minimalist", "minimalistic"],

    # Eclectic / Industrial / Other
    "Eclectic"                  => ["eclectic", "eclecticism", "eclectic style"],
    "Industrial"                => ["industrial", "industrial architecture", "post-industrial", "warehouse"],
    "Skyscraper"                => ["skyscraper", "skyscraper style", "skyscraper design"],
    "Chicago School"            => ["chicago school"],
    "Chateauesque"              => ["chateauesque"],
    "Indo-Saracenic"            => ["indo-saracenic"],
    "Mayan Revival"             => ["mayan revival"],
  }.freeze

  # Build a reverse lookup: lowercase variant -> canonical name
  VARIANT_TO_CANONICAL = {}.tap do |map|
    CANONICAL_STYLES.each do |canonical, variants|
      variants.each { |v| map[v.downcase.strip] = canonical }
      map[canonical.downcase.strip] = canonical
    end
  end.freeze

  def self.normalize(style)
    return nil if style.nil?
    return style if style.is_a?(Array)

    cleaned = style.to_s.strip
    cleaned = remove_percentage(cleaned)
    cleaned = cleaned.gsub(/[:\-–—]?\s*\d+\s*%?\s*$/, '').strip
    cleaned = cleaned.gsub(/\A[\s:]+|[\s:]+\z/, '')

    lookup = cleaned.downcase.strip.tr('-', ' ').gsub(/\s+/, ' ')

    # Direct match
    return VARIANT_TO_CANONICAL[lookup] if VARIANT_TO_CANONICAL.key?(lookup)

    # Remove common suffixes/prefixes
    simplified = lookup
      .gsub(/\s*(style|architecture|design|movement|school|revival|influence|influences|instances|in real life)\s*/i, ' ')
      .strip
      .gsub(/\s+/, ' ')

    return VARIANT_TO_CANONICAL[simplified] if VARIANT_TO_CANONICAL.key?(simplified)

    # Check if any canonical variant is contained in the input
    VARIANT_TO_CANONICAL.each do |variant, canonical|
      next if variant.length < 4
      return canonical if lookup.include?(variant)
    end

    # If no match, return cleaned-up title case
    cleaned.split.map(&:capitalize).join(' ')
  end

  def self.remove_percentage(style)
    style.gsub(/\s*\d+%/, '').strip
  end

  def self.normalize_array(styles)
    Array(styles)
      .map { |style| normalize(style) }
      .compact
      .reject(&:blank?)
      .uniq
  end

  # The canonical style list formatted for GPT prompts.
  # This is the ONLY place styles should be defined — prompt derives from here.
  def self.style_list_for_prompt
    CANONICAL_STYLES.keys.sort.join(", ")
  end

  def self.all_canonical_styles
    CANONICAL_STYLES.keys.sort
  end

  def self.known?(style)
    normalized = normalize(style)
    CANONICAL_STYLES.key?(normalized)
  end
end
