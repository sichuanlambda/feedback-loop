class UserLevel < ApplicationRecord
  belongs_to :user

  validates :level, presence: true, numericality: { greater_than: 0 }
  validates :total_points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :level_reached_at, presence: true

  scope :by_level, -> { order(level: :desc, total_points: :desc) }
  scope :by_points, -> { order(total_points: :desc) }

  # Level thresholds (points needed to reach each level)
  LEVEL_THRESHOLDS = {
    1 => 0,
    2 => 25,
    3 => 75,
    4 => 150,
    5 => 275,
    6 => 450,
    7 => 700,
    8 => 1000,
    9 => 1400,
    10 => 1900,
    11 => 2500,
    12 => 3200,
    13 => 4000,
    14 => 5000,
    15 => 6200
  }.freeze

  def self.for_leaderboard
    # Exclude Atlas admin account from leaderboards
    joins(:user)
      .where.not(users: { email: 'atlas@architecturehelper.com' })
      .by_level
  end

  def self.find_or_create_for_user(user)
    find_or_create_by(user: user) do |user_level|
      user_level.level = 1
      user_level.total_points = 0
      user_level.buildings_analyzed = 0
      user_level.styles_collected = 0
      user_level.achievements_earned = 0
      user_level.level_reached_at = Time.current
      user_level.last_activity_at = Time.current
    end
  end

  def calculate_level_from_points
    LEVEL_THRESHOLDS.reverse_each do |level, threshold|
      return level if total_points >= threshold
    end
    1 # Minimum level
  end

  def points_to_next_level
    current_level = calculate_level_from_points
    next_level = current_level + 1
    next_threshold = LEVEL_THRESHOLDS[next_level]
    
    return nil if next_threshold.nil? # Max level reached
    
    next_threshold - total_points
  end

  def level_progress_percentage
    current_level = calculate_level_from_points
    next_level = current_level + 1
    current_threshold = LEVEL_THRESHOLDS[current_level]
    next_threshold = LEVEL_THRESHOLDS[next_level]
    
    return 100 if next_threshold.nil? # Max level reached
    
    level_points = total_points - current_threshold
    level_span = next_threshold - current_threshold
    
    (level_points.to_f / level_span * 100).round(1)
  end

  def update_stats!
    return if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    self.total_points = user.building_contributions.sum(:points_awarded)
    self.buildings_analyzed = user.building_analyses.count
    self.styles_collected = user.user_style_collections.count
    self.achievements_earned = user.user_achievements.count
    self.last_activity_at = Time.current

    new_level = calculate_level_from_points
    if new_level > level
      self.level = new_level
      self.level_reached_at = Time.current
    end

    save!
  end
end