class BuildingAnalysis < ApplicationRecord
  belongs_to :user

  def self.total_count
    BuildingAnalysis.count
  end
end
