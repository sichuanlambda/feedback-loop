class BuildingAnalysis < ApplicationRecord
  belongs_to :user

  def self.total_count
    BuildingAnalysis.count
  end

  def self.style_frequency(user_id)
    styles = BuildingAnalysis.where(user_id: user_id).pluck(:h3_contents).map do |h3_content|
      JSON.parse(h3_content)
    end.flatten
    styles.tally
  end
end
