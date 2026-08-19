class BuildingAnalysis < ApplicationRecord
  belongs_to :user

  # Virtual attribute for distance calculations (used in API)
  attr_accessor :distance

  # Buildings whose image can actually render in an <img> tag: absolute http(s)
  # URL, excluding the legacy screenshotsearcher bucket (public reads 403).
  scope :with_showable_image, -> {
    where("image_url LIKE 'http%'")
      .where.not("image_url LIKE '%screenshotsearcher.s3%'")
  }

  # Use the 'address' attribute for geocoding
  geocoded_by :address
  # Auto-fetch coordinates after validation, if address changed
  after_validation :geocode, if: ->(obj){ obj.address.present? and obj.address_changed? }

  # Clean display helpers — treat nil, blank, and "N/A" as absent
  def display_name
    name.presence&.then { |n| n == 'N/A' ? nil : n }
  end

  def display_address
    address.presence&.then { |a| a == 'N/A' ? nil : a }
  end

  # Method to generate Google Street View URL
  def street_view_url(size: "600x400")
    api_key = Rails.application.credentials.google_maps[:api_key]
    "https://maps.googleapis.com/maps/api/streetview?size=#{size}&location=#{latitude},#{longitude}&key=#{api_key}"
  end

  # Deterministic shuffle that changes daily, so library pages mix cities
  # instead of showing batch-imported walls of one city. Postgres in
  # production; SQLite in development lacks md5(), so hash with what's there.
  def self.daily_shuffle
    if connection.adapter_name.match?(/postg/i)
      order(Arel.sql("md5(id::text || '#{Date.today}')"))
    else
      order(Arel.sql("(id * 2654435761 + #{Date.today.jd}) % 1000000"))
    end
  end

  def self.total_count
    BuildingAnalysis.count
  end

  def self.style_frequency(user_id)
    h3_contents = BuildingAnalysis.where(user_id: user_id).pluck(:h3_contents)
    all_styles = []

    h3_contents.each do |content|
      next if content.blank?
      begin
        styles = StyleNormalizer.normalize_array(JSON.parse(content))
        all_styles.concat(styles)
      rescue JSON::ParserError
        next
      end
    end

    all_styles.tally
  end

  before_save :normalize_styles

  private

  def normalize_styles
    return if h3_contents.blank?

    begin
      styles = h3_contents.is_a?(String) ? JSON.parse(h3_contents) : Array(h3_contents)
      normalized = StyleNormalizer.normalize_array(styles)
      self.h3_contents = normalized.to_json
    rescue JSON::ParserError
      # Leave as-is if we can't parse
    end
  end
end
