module StyleNormalizer
  # Canonical style taxonomy with synonyms/variants that map to each canonical name.
  # When GPT or user input produces a variant, we normalize to the canonical form.
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

    # 18th-19th Century Revival & Classical
    "Neoclassical"              => ["neoclassical", "neoclassicism", "classical revival", "greek revival", "federal", "federal style", "stripped classicism", "new classical"],
    "Beaux-Arts"                => ["beaux-arts", "beaux arts", "city beautiful", "city beautiful movement"],
    "Victorian"                 => ["victorian", "folk victorian", "queen anne", "second empire", "edwardian"],
    "Colonial Revival"          => ["colonial", "colonial revival", "dutch colonial", "dutch colonial revival", "georgian", "georgian revival", "cape cod"],
    "Tudor Revival"             => ["tudor", "tudor revival", "jacobean", "elizabethan", "scottish baronial"],
    "Italianate"                => ["italianate"],
    "Romanesque Revival"        => ["romanesque revival", "richardsonian romanesque"],

    # Arts & Crafts / Early 20th Century
    "Arts and Crafts"           => ["arts and crafts", "arts & crafts", "art & crafts", "craftsman", "shingle style", "american foursquare"],
    "Art Nouveau"               => ["art nouveau", "vienna secession", "jugendstil", "japonism", "japonisme"],
    "Art Deco"                  => ["art deco", "zigzag moderne", "streamline moderne", "art moderne"],

    # Mission / Spanish / Mediterranean
    "Mediterranean Revival"     => ["mediterranean", "mediterranean revival", "spanish colonial", "spanish colonial revival", "spanish revival", "mission", "mission revival", "pueblo", "pueblo revival", "territorial revival"],

    # Modernism (the big bucket — this is where most overlap happens)
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

    # Regional / Other
    "Chicago School"            => ["chicago school"],
    "Chateauesque"              => ["chateauesque"],
    "Indo-Saracenic"            => ["indo-saracenic", "saracen"],
    "Mayan Revival"             => ["mayan revival"],
  }.freeze

  # Build a reverse lookup: lowercase variant → canonical name
  VARIANT_TO_CANONICAL = {}.tap do |map|
    CANONICAL_STYLES.each do |canonical, variants|
      variants.each { |v| map[v.downcase.strip] = canonical }
      # Also map the canonical name itself
      map[canonical.downcase.strip] = canonical
    end
  end.freeze

  def self.normalize(style)
    return nil if style.nil?
    return style if style.is_a?(Array)

    cleaned = style.to_s.strip
    cleaned = remove_percentage(cleaned)
    cleaned = cleaned.gsub(/[:\-–—]?\s*\d+\s*%?\s*$/, '').strip  # Remove trailing percentages
    cleaned = cleaned.gsub(/\A[\s:]+|[\s:]+\z/, '')               # Remove leading/trailing colons

    lookup = cleaned.downcase.strip

    # Direct match
    return VARIANT_TO_CANONICAL[lookup] if VARIANT_TO_CANONICAL.key?(lookup)

    # Try progressively looser matching
    # 1. Remove common suffixes/prefixes
    simplified = lookup
      .gsub(/\s*(style|architecture|design|movement|school|revival)\s*/i, ' ')
      .strip
      .gsub(/\s+/, ' ')

    return VARIANT_TO_CANONICAL[simplified] if VARIANT_TO_CANONICAL.key?(simplified)

    # 2. Check if any canonical variant is contained in the input
    VARIANT_TO_CANONICAL.each do |variant, canonical|
      next if variant.length < 4 # Skip very short variants to avoid false positives
      return canonical if lookup.include?(variant)
    end

    # 3. If no match, return cleaned-up title case
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
      .uniq  # Remove duplicates after normalization
  end

  # Returns all canonical style names (useful for dropdowns, filters)
  def self.all_canonical_styles
    CANONICAL_STYLES.keys.sort
  end

  # Check if a style string would normalize to a known canonical style
  def self.known?(style)
    normalized = normalize(style)
    CANONICAL_STYLES.key?(normalized)
  end
end
