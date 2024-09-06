class BuildingAnalysis < ApplicationRecord
  belongs_to :user

  # Use the 'address' attribute for geocoding
  geocoded_by :address
  # Auto-fetch coordinates after validation, if address changed
  after_validation :geocode, if: ->(obj){ obj.address.present? and obj.address_changed? }

  # Method to generate Google Street View URL
  def street_view_url(size: "600x400")
    api_key = Rails.application.credentials.google_maps[:api_key]
    "https://maps.googleapis.com/maps/api/streetview?size=#{size}&location=#{latitude},#{longitude}&key=#{api_key}"
  end

  def self.total_count
    BuildingAnalysis.count
  end

  def self.style_frequency(user_id)
    h3_contents = BuildingAnalysis.where(user_id: user_id).pluck(:h3_contents)
    all_styles = []

    h3_contents.each do |content|
      next if content.blank? # Skip if content is nil or empty
      styles_with_percentages = JSON.parse(content)

      styles = styles_with_percentages.map do |style_with_percentage|
        match = style_with_percentage.match(/^(.*?)\s*\d+%$/)
        match ? match[1].strip : nil
      end.compact

      all_styles.concat(styles)
    end

    all_styles.tally
  end

  before_save :normalize_styles

  private

  def normalize_styles
    self.h3_contents = StyleNormalizer.normalize_array(h3_contents)
  end
end
