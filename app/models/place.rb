class Place < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :latitude, presence: true, numericality: { greater_than: -90, less_than: 90 }
  validates :longitude, presence: true, numericality: { greater_than: -180, less_than: 180 }
  validates :zoom_level, numericality: { greater_than: 0, less_than: 20 }, allow_nil: true
  
  before_validation :generate_slug, on: :create
  after_update :update_sitemap_if_published_changed
  
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :with_images, -> { where.not(hero_image_url: [nil, '']) }
  scope :needs_content, -> { where(content_generated_at: nil) }

  def to_param
    slug
  end

  def coordinates
    [latitude, longitude]
  end

  def map_center
    {
      lat: latitude,
      lng: longitude,
      zoom: zoom_level || 12
    }
  end

  def has_hero_image?
    hero_image_url.present?
  end

  def has_content?
    content.present?
  end

  def needs_content_generation?
    content.blank? && content_generated_at.nil?
  end

  def needs_image_generation?
    hero_image_url.blank?
  end

  def building_analyses_in_place
    BuildingAnalysis.where(
      latitude: (latitude - 0.1)..(latitude + 0.1),
      longitude: (longitude - 0.1)..(longitude + 0.1),
      visible_in_library: true
    )
  end

  def best_representative_image
    return hero_image_url if hero_image_url.present?
    return representative_image_url if representative_image_url.present?
    
    # Fallback to best building analysis image
    best_building = building_analyses_in_place
      .where.not(image_url: [nil, ''])
      .order('RANDOM()')
      .first
    
    best_building&.image_url
  end

  def architectural_styles_summary
    buildings = building_analyses_in_place
    return [] if buildings.empty?
    
    style_counts = Hash.new(0)
    buildings.each do |building|
      next unless building.h3_contents.present?
      
      begin
        styles = JSON.parse(building.h3_contents)
        styles.each { |style| style_counts[style] += 1 }
      rescue JSON::ParserError
        next
      end
    end
    
    style_counts.sort_by { |_style, count| -count }.first(5)
  end

  def regenerate_slug!
    self.slug = nil
    generate_slug
    save!
  end

  def self.regenerate_all_slugs!
    find_each do |place|
      place.regenerate_slug!
    end
  end

  private

  def generate_slug
    return if slug.present?
    
    base_slug = name.parameterize
    counter = 0
    new_slug = base_slug
    
    while Place.exists?(slug: new_slug)
      counter += 1
      new_slug = "#{base_slug}-#{counter}"
    end
    
    self.slug = new_slug
  end

  def update_sitemap_if_published_changed
    if saved_change_to_published?
      # Queue sitemap update in background
      UpdateSitemapJob.perform_later
    end
  end
end 