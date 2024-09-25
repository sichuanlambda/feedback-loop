module StyleNormalizer
  STYLE_MAPPINGS = {
    /\b(arts?[\s&-]*crafts?|craftsman)\b/i => "Arts and Crafts",
    /\bart[\s-]*deco\b/i => "Art Deco",
    /\bmid[\s-]*century[\s-]*modern\b/i => "Mid-Century Modern",
    /\bmodern\b/i => "Modern",
    /\bcontemporary\b/i => "Contemporary",
    /\bvictorian\b/i => "Victorian",
    /\bcolonial\b/i => "Colonial",
    /\bmediterranean\b/i => "Mediterranean",
    /\bfarmhouse\b/i => "Farmhouse",
    /\bcraftsman\b/i => "Craftsman",
    /\branch\b/i => "Ranch",
    /\btudor\b/i => "Tudor",
    /\bminimalist\b/i => "Minimalist",
    /\bscandinavian\b/i => "Scandinavian",
    /\bindustrial\b/i => "Industrial",
    /\brustic\b/i => "Rustic",
    /\btraditional\b/i => "Traditional",
    /\btransitional\b/i => "Transitional",
    /\beclectic\b/i => "Eclectic",
    /\bcoastal\b/i => "Coastal",
    /\btropical\b/i => "Tropical",
    /\basian\b/i => "Asian",
    /\bjapanese\b/i => "Japanese",
    /\bzen\b/i => "Zen",
    /\bart[\s-]*nouveau\b/i => "Art Nouveau",
    /\bbaroque\b/i => "Baroque",
    /\brococo\b/i => "Rococo",
    /\bneoclassical\b/i => "Neoclassical",
    /\bgothic\b/i => "Gothic",
    /\brenaissance\b/i => "Renaissance",
    /\bshabby[\s-]*chic\b/i => "Shabby Chic",
    /\bfrench[\s-]*country\b/i => "French Country",
    /\bsouthwestern\b/i => "Southwestern",
    /\bhollywood[\s-]*regency\b/i => "Hollywood Regency",
    /\bart[\s-]*moderne\b/i => "Art Moderne",
    /\bbrutalist\b/i => "Brutalist",
    /\bpostmodern\b/i => "Postmodern",
    /\bdeconstructivist\b/i => "Deconstructivist",
    /\bhigh[\s-]*tech\b/i => "High-Tech",
    /\borganic\b/i => "Organic",
    /\bprairie[\s-]*style\b/i => "Prairie Style",
    /\bshaker\b/i => "Shaker",
    /\bbauhaus\b/i => "Bauhaus",
    /\bgreek[\s-]*revival\b/i => "Greek Revival",
    /\bitalian[\s-]*renaissance\b/i => "Italian Renaissance",
    /\bspanish[\s-]*colonial\b/i => "Spanish Colonial",
    /\bcape[\s-]*cod\b/i => "Cape Cod",
    /\bgeorgian\b/i => "Georgian",
    /\bfederal\b/i => "Federal",
    /\bqueen[\s-]*anne\b/i => "Queen Anne",
    /\bmission[\s-]*revival\b/i => "Mission Revival",
    /\bpueblo[\s-]*revival\b/i => "Pueblo Revival",
    /\bbeaux[\s-]*arts\b/i => "Beaux-Arts",
    /\binternational[\s-]*style\b/i => "International Style",
    /\bcontemporary[\s-]*modern\b/i => "Contemporary Modern",
    /\bmodern[\s-]*farmhouse\b/i => "Modern Farmhouse",
    /\bboho\b/i => "Bohemian",
    /\bmediterranean[\s-]*revival\b/i => "Mediterranean Revival",
    /\bspanish[\s-]*revival\b/i => "Spanish Revival",
    /\bfrench[\s-]*provincial\b/i => "French Provincial",
    /\bchalet\b/i => "Chalet",
    /\bprovincial\b/i => "Provincial",
    /\bsouthern\b/i => "Southern",
    /\bnordic\b/i => "Nordic",
    /\bwabi[\s-]*sabi\b/i => "Wabi-Sabi",
    /\blagom\b/i => "Lagom",
    /\bhygge\b/i => "Hygge",
    /\bfeng[\s-]*shui\b/i => "Feng Shui",
    /\bvintage\b/i => "Vintage",
    /\bretro\b/i => "Retro",
    /\bsteampunk\b/i => "Steampunk",
    /\bbiophilic\b/i => "Biophilic",
    /\bsustainable\b/i => "Sustainable",
    /\beco[\s-]*friendly\b/i => "Eco-Friendly",
    /\bgreen\b/i => "Green",
    /\bsmart[\s-]*home\b/i => "Smart Home",
    /\bminimalism\b/i => "Minimalist",
    /\bmaximalism\b/i => "Maximalist",
    /\bgrandmillennial\b/i => "Grandmillennial",
    /\bcottagecore\b/i => "Cottagecore",
    /\bjaponisme\b/i => "Japonisme",
    /\bwabi[\s-]*sabi\b/i => "Wabi-Sabi",
    /\bhampton\b/i => "Hamptons",
    /\bcoastal[\s-]*grandmother\b/i => "Coastal Grandmother",
    /\bscandi\b/i => "Scandinavian",
    # Add more specific multi-word styles
    /\bscandinavian[\s-]*minimalist\b/i => "Scandinavian Minimalist",
    /\bindustrial[\s-]*loft\b/i => "Industrial Loft",
    /\bboho[\s-]*eclectic\b/i => "Boho Eclectic",
    /\bfarmhouse[\s-]*chic\b/i => "Farmhouse Chic",
    /\brustic[\s-]*modern\b/i => "Rustic Modern",
    /\bcoastal[\s-]*farmhouse\b/i => "Coastal Farmhouse",
    /\bmodern[\s-]*industrial\b/i => "Modern Industrial",
    /\btraditional[\s-]*contemporary\b/i => "Traditional Contemporary",
    /\beclectic[\s-]*bohemian\b/i => "Eclectic Bohemian",
    /\bminimalist[\s-]*scandinavian\b/i => "Minimalist Scandinavian",
    # Additional styles
    /\bitalianate\b/i => "Italianate",
    /\bbyzantine\b/i => "Byzantine",
    /\bromanesque\b/i => "Romanesque",
    /\bcarpenter[\s-]*gothic\b/i => "Carpenter Gothic",
    /\bchateauesque\b/i => "Chateauesque",
    /\bexotic[\s-]*revival\b/i => "Exotic Revival",
    /\bfolk[\s-]*victorian\b/i => "Folk Victorian",
    /\bitalian[\s-]*renaissance\b/i => "Italian Renaissance",
    /\bjacobean\b/i => "Jacobean",
    /\bmission\b/i => "Mission",
    /\bneogothic\b/i => "Neo-Gothic",
    /\bneorenaissance\b/i => "Neo-Renaissance",
    /\bneoromanesque\b/i => "Neo-Romanesque",
    /\bneovernacular\b/i => "Neo-Vernacular",
    /\bpalladian\b/i => "Palladian",
    /\bpicturesque\b/i => "Picturesque",
    /\bpueblo\b/i => "Pueblo",
    /\bregency\b/i => "Regency",
    /\bromantic\b/i => "Romantic",
    /\bsecond[\s-]*empire\b/i => "Second Empire",
    /\bspanish[\s-]*revival\b/i => "Spanish Revival",
    /\bstreamline[\s-]*moderne\b/i => "Streamline Moderne",
    /\bvernacular\b/i => "Vernacular",
    /\bwest[\s-]*indian\b/i => "West Indian"
  }

  def self.normalize(style)
    return nil if style.nil?
    return style if style.is_a?(Array)

    normalized = style.to_s.strip.downcase
    normalized = remove_percentage(normalized)

    # Check for exact matches first
    STYLE_MAPPINGS.each do |pattern, replacement|
      return replacement if normalized.match?(/\A#{pattern}\z/i)
    end

    # If no exact match, check for partial matches
    STYLE_MAPPINGS.each do |pattern, replacement|
      return replacement if normalized.match?(pattern)
    end

    # If no match found, capitalize each word
    normalized.split.map(&:capitalize).join(' ')
  end

  def self.remove_percentage(style)
    style.gsub(/\s*\d+%/, '').strip
  end

  def self.normalize_array(styles)
    Array(styles).map { |style| normalize(style) }.compact.uniq
  end
end
