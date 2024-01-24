class BuildingAnalysis < ApplicationRecord
  belongs_to :user

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
end
