require 'open-uri'
require 'json'

# Google Street View lookups for address-only analyses. The image endpoint
# answers 200 with a grey "Sorry, we have no imagery here" picture when it has
# nothing, so availability has to be checked on the (free) metadata endpoint
# before an image is fetched, shown or analyzed.
module StreetView
  BASE = 'https://maps.googleapis.com/maps/api/streetview'.freeze
  # Google's default search radius is 50m. Landmarks set back from the road
  # need a wider one; past this the photo is usually of a different building.
  RADII = [nil, 150].freeze

  # { radius: } for the tightest radius with imagery, or nil when Street View
  # has no photo of the address.
  def self.find(address)
    return nil if address.blank?

    RADII.each do |radius|
      body = URI.open("#{BASE}/metadata?#{query(address, radius)}", open_timeout: 4, read_timeout: 4).read
      return { radius: radius } if JSON.parse(body)['status'] == 'OK'
    end
    nil
  rescue StandardError => e
    # A lookup that fails must not block analyses: carry on as before the check existed
    Rails.logger.warn "Street View metadata lookup failed: #{e.class} #{e.message}"
    { radius: nil }
  end

  def self.image_url(address, radius: nil, size: '600x400')
    "#{BASE}?size=#{size}&#{query(address, radius)}"
  end

  def self.query(address, radius)
    params = { location: address, key: Rails.application.credentials.google_maps[:api_key] }
    params[:radius] = radius.to_i if radius.present?
    params.to_query
  end
end
