class BlogPost < ApplicationRecord
  # Each post carries the CTA best matched to its topic:
  #   restyle -> /restyle           (interior, decor, room-makeover topics)
  #   design  -> /architecture_designer/step1 (house plans, tiny homes, build-your-own)
  #   styles  -> style explorer     (style guides, history, terminology)
  #   city    -> /places            (city and travel architecture)
  #   analyze -> /architecture_explorer/new (identification and everything else)
  CTA_CATEGORIES = %w[analyze restyle design styles city].freeze

  # Style words that map to a real style page in the building library,
  # so style posts can deep-link instead of landing on the generic index.
  STYLE_PAGE_KEYWORDS = {
    'victorian' => 'Victorian',
    'gothic' => 'Gothic',
    'neoclassical' => 'Neoclassical',
    'bauhaus' => 'Bauhaus',
    'colonial' => 'Colonial',
    'mediterranean' => 'Mediterranean',
    'art deco' => 'Art Deco',
    'renaissance' => 'Renaissance',
    'craftsman' => 'Craftsman',
    'cape cod' => 'Cape Cod',
    'deconstructivist' => 'Deconstructivism',
    'modernist' => 'Modernist'
  }.freeze

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :title, presence: true
  validates :cta_category, inclusion: { in: CTA_CATEGORIES }, allow_nil: true

  before_validation :assign_cta_category, if: -> { cta_category.blank? }

  scope :published, -> { where(published: true).order(published_at: :desc, id: :desc) }

  def to_param
    slug
  end

  def self.infer_cta_category(title, slug)
    text = "#{title} #{slug}".downcase

    # Strong signals first: named styles and religious/historical architecture
    # beat generic interior words (chapel *seating*, neoclassical *in Europe*),
    # and "plans" posts are design posts even when they mention bedrooms.
    style_strong = /chapel|monast|refectory|chapter.house|mosque|pagoda|cathedral|church|sacred|doric|ionic|corinthian|deconstructivi|neoclassical|bauhaus|renaissance|golden.ratio|brunelleschi|djenne/
    design_strong = /plans\b|floor.plan|design.generator|home.designer/
    interior = /interior|decor|furniture|room|bathroom|kitchen|mudroom|attic|makeover|staging|seating|flooring|desk|bed\b|innendesign|interieur|interiores|freestyle|vaporwave|cafe|restaurant|hotel|store|mansion living/
    build    = /tiny.?house|tiny.?home|cottage|farmhouse|greenhouse|small.house|small.wood|mobile.home|porch|exterior|dollhouse|stilts|passive.solar|green.roof|green.wall|vertical.garden|daylighting|ventilation|rainwater|flood|3d.printing|4d.printing|composite/
    place    = /famous.buildings|city|cities|urban|amsterdam|denver|new.york|hague|cordoba|florence|singapore|monument|public.space|civic|zoning|landslide|europe\b|european.buildings|oldest.building/
    style    = /style|gothic|victorian|colonial|mediterranean|ritual|religio|dutch|french|new.england|indian|art.deco|aesthetic|history|historical|heritage|symbolism|craftsman|cape.cod|70s|old.world/

    return 'styles'  if text =~ style_strong
    return 'design'  if text =~ design_strong
    return 'restyle' if text =~ interior
    return 'design'  if text =~ build
    return 'city'    if text =~ place
    return 'styles'  if text =~ style

    'analyze'
  end

  # "/building_library/styles/Victorian" when the title names a style we
  # have a library page for, else nil (the styles CTA falls back to /styles).
  def style_page_path
    text = "#{title} #{slug}".downcase
    STYLE_PAGE_KEYWORDS.each do |keyword, style_name|
      return "/building_library/styles/#{ERB::Util.url_encode(style_name)}" if text.include?(keyword)
    end
    nil
  end

  def cta_partial
    CTA_CATEGORIES.include?(cta_category) ? cta_category : 'analyze'
  end

  private

  def assign_cta_category
    self.cta_category = self.class.infer_cta_category(title, slug)
  end
end
