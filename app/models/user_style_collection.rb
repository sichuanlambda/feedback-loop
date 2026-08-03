class UserStyleCollection < ApplicationRecord
  belongs_to :user

  validates :style_name, presence: true, uniqueness: { scope: :user_id }
  validates :building_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :first_collected_at, presence: true

  scope :by_building_count, -> { order(building_count: :desc) }
  scope :recently_collected, -> { order(first_collected_at: :desc) }

  before_save :update_last_updated_at

  def add_building(building_analysis)
    building_ids_array = building_ids || []
    unless building_ids_array.include?(building_analysis.id)
      building_ids_array << building_analysis.id
      self.building_ids = building_ids_array
      self.building_count = building_ids_array.length
      self.last_updated_at = Time.current
      save!
    end
  end

  def remove_building(building_analysis)
    building_ids_array = building_ids || []
    if building_ids_array.delete(building_analysis.id)
      self.building_ids = building_ids_array
      self.building_count = building_ids_array.length
      self.last_updated_at = Time.current
      save!
    end
  end

  def buildings
    return BuildingAnalysis.none if building_ids.blank?
    BuildingAnalysis.where(id: building_ids)
  end

  def self.for_leaderboard
    # Exclude Atlas admin account from leaderboards
    joins(:user)
      .where.not(users: { email: 'atlas@architecturehelper.com' })
      .group(:user_id)
      .order('SUM(building_count) DESC')
  end

  private

  def update_last_updated_at
    self.last_updated_at = Time.current if building_count_changed?
  end
end