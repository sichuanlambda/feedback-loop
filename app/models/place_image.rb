# One hand-picked photo per city guide, read from config/place_images.yml.
# `rake places:set_hero_images` copies the files to S3; the credit shown under the
# photo on the guide page comes from here.
class PlaceImage
  SOURCE = 'wikimedia'.freeze
  SIZES = { hero: 1600, card: 640 }.freeze
  USER_AGENT = 'ArchitectureHelper/1.0 (https://architecturehelper.com)'.freeze

  attr_reader :name, :file, :author, :license, :alt

  def self.all
    @all ||= YAML.safe_load_file(Rails.root.join('config/place_images.yml')).to_h do |name, attrs|
      [name, new(name, attrs)]
    end
  end

  def self.for(place)
    all[place.name] if place.image_source == SOURCE
  end

  def initialize(name, attrs)
    @name = name
    @file = attrs.fetch('file')
    @author = attrs.fetch('author')
    @license = attrs.fetch('license')
    @alt = attrs.fetch('alt')
  end

  def download_url(size)
    "https://commons.wikimedia.org/wiki/Special:FilePath/#{ERB::Util.url_encode(file)}?width=#{SIZES.fetch(size)}"
  end

  def source_url
    "https://commons.wikimedia.org/wiki/File:#{ERB::Util.url_encode(file.tr(' ', '_'))}"
  end

  def s3_key(size)
    "uploads/places/#{name.parameterize}_#{size}.jpg"
  end

  def credit
    "#{author}, #{license}"
  end
end
