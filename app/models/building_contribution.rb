class BuildingContribution < ApplicationRecord
  belongs_to :user
  belongs_to :building_analysis

  validates :contribution_type, presence: true
  validates :contributed_at, presence: true
  validates :points_awarded, presence: true, numericality: { greater_than_or_equal_to: 0 }

  CONTRIBUTION_TYPES = %w[
    submission analysis photo style_identification
    accuracy_improvement location_verification
  ].freeze

  validates :contribution_type, inclusion: { in: CONTRIBUTION_TYPES }

  scope :recent, -> { order(contributed_at: :desc) }
  scope :by_type, ->(type) { where(contribution_type: type) }
  scope :with_points, -> { where('points_awarded > 0') }

  # Point values for different contribution types
  POINT_VALUES = {
    'submission' => 10,
    'analysis' => 5,
    'photo' => 3,
    'style_identification' => 2,
    'accuracy_improvement' => 8,
    'location_verification' => 5
  }.freeze

  def self.for_leaderboard
    # Exclude Atlas admin account from leaderboards
    joins(:user)
      .where.not(users: { email: 'atlas@architecturehelper.com' })
      .group(:user_id)
      .order('SUM(points_awarded) DESC')
  end

  def self.create_for_building_analysis(user, building_analysis, type = 'submission')
    return if user.email == 'atlas@architecturehelper.com' # Skip Atlas admin

    create!(
      user: user,
      building_analysis: building_analysis,
      contribution_type: type,
      contributed_at: Time.current,
      points_awarded: POINT_VALUES[type] || 0,
      description: "#{type.humanize} for #{building_analysis.display_name || 'building'}"
    )
  end
end