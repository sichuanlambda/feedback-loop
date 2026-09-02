# Generated editorial content for a "<Style> Architecture in <City>" page
# (/styles/:style/in/:city). The page itself is data-driven and renders with
# or without a row here; a row adds the AI-written intro and FAQ.
class StyleCityPage < ApplicationRecord
  # Pairs with fewer buildings than this are served noindex and left out of
  # the sitemap: a three-card listing is a thin page, not a landing page.
  MIN_BUILDINGS = 3

  validates :style_name, :city_slug, :city_name, presence: true
  validates :city_slug, uniqueness: { scope: :style_name }

  scope :generated, -> { where.not(generated_at: nil) }

  def self.path_for(style_name, city_name)
    "/styles/#{style_name.parameterize}/in/#{city_name.parameterize}"
  end

  def path
    self.class.path_for(style_name, city_name)
  end

  def faqs
    Array(faq).map { |f| f.is_a?(Hash) ? f.with_indifferent_access : nil }.compact
  end

  # { [canonical_style, city] => visible building count }, from the buildings'
  # city column (the same field style_in_city filters on, so counts here match
  # what the page will list). Cached briefly: it scans every visible building.
  def self.pair_counts
    Rails.cache.fetch('style_city_page/pair_counts', expires_in: 15.minutes) do
      counts = Hash.new(0)
      BuildingAnalysis.where(visible_in_library: true)
                      .where.not(city: [nil, '', 'N/A'])
                      .pluck(:city, :h3_contents).each do |city, h3|
        next if h3.blank?
        styles = begin
          StyleNormalizer.normalize_array(JSON.parse(h3))
        rescue JSON::ParserError
          []
        end
        styles.each { |style| counts[[style, city]] += 1 }
      end
      counts
    end
  end

  def self.indexable_pairs(min: MIN_BUILDINGS)
    pair_counts.select { |_, count| count >= min }
  end

  def self.pairs_for_style(style_name)
    pair_counts.select { |(style, _), _| style == style_name }
               .map { |(_, city), count| [city, count] }
               .sort_by { |_, count| -count }
  end

  def self.pairs_for_city(city_name)
    pair_counts.select { |(_, city), _| city.casecmp?(city_name.to_s) }
               .map { |(style, _), count| [style, count] }
               .sort_by { |_, count| -count }
  end

  # Map a URL slug back to the city string stored on buildings, so
  # "krakow" finds "Kraków" and "den-haag" finds "Den Haag".
  def self.resolve_city(slug)
    return nil if slug.blank?
    wanted = slug.to_s.parameterize
    Rails.cache.fetch('style_city_page/cities', expires_in: 15.minutes) do
      BuildingAnalysis.where(visible_in_library: true)
                      .where.not(city: [nil, '', 'N/A'])
                      .distinct.pluck(:city)
    end.detect { |city| city.parameterize == wanted }
  end
end
