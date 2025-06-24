class Place < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :latitude, presence: true, numericality: { greater_than: -90, less_than: 90 }
  validates :longitude, presence: true, numericality: { greater_than: -180, less_than: 180 }
  validates :zoom_level, numericality: { greater_than: 0, less_than: 20 }, allow_nil: true
  
  before_validation :generate_slug, on: :create
  
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }

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
end 