class UserEvent < ApplicationRecord
  belongs_to :user, optional: true

  scope :recent, -> { where(created_at: 30.days.ago..) }
  scope :by_type, ->(t) { where(event_type: t) }

  before_save :classify_agent

  # Real-visitor rows. Crawlers are flagged on save (and were backfilled with
  # `rake events:backfill_bot`); server-originated rows have no agent and count.
  scope :human, -> { where(bot: false) }

  def self.track(event_type:, user: nil, session_id: nil, request: nil, metadata: {})
    ip_hash = if request&.remote_ip
      Digest::SHA256.hexdigest(request.remote_ip)
    end

    create!(
      event_type: event_type,
      user: user,
      session_id: session_id,
      metadata: metadata,
      ip_hash: ip_hash,
      user_agent: request&.user_agent
    )
  rescue => e
    Rails.logger.error "UserEvent.track failed: #{e.message}"
    nil
  end

  private

  def classify_agent
    self.bot = user_agent.present? && BotDetector.bot?(user_agent)
    true
  end
end
