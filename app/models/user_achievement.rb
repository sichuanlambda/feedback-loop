class UserAchievement < ApplicationRecord
  belongs_to :user

  validates :achievement_key, presence: true, uniqueness: { scope: :user_id }
  validates :earned_at, presence: true
  validates :badge_count, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { order(earned_at: :desc) }
  scope :by_key, ->(key) { where(achievement_key: key) }

  # Common achievement keys
  ACHIEVEMENT_KEYS = %w[
    explorer_bronze explorer_silver explorer_gold
    collector_bronze collector_silver collector_gold
    style_master_art_deco style_master_modern style_master_victorian
    city_expert_nyc city_expert_chicago city_expert_sf
    first_building first_style_collection ten_buildings
    hundred_buildings diversity_champion speed_analyzer
  ].freeze

  def self.for_leaderboard
    # Exclude Atlas admin account from leaderboards
    joins(:user)
      .where.not(users: { email: 'atlas@architecturehelper.com' })
      .group(:user_id)
      .order('COUNT(*) DESC')
  end
end