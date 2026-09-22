class UserEvent < ApplicationRecord
  belongs_to :user, optional: true

  scope :recent, -> { where(created_at: 30.days.ago..) }
  scope :by_type, ->(t) { where(event_type: t) }

  # Rows written before 2026-09-22 include crawler traffic (bots have been
  # skipped at write time since). Server-originated events carry no user agent
  # and are kept. SQLite (dev/test) has no regex operator, so it gets LIKEs.
  scope :human, -> {
    if connection.adapter_name.match?(/postg/i)
      where('user_agent IS NULL OR user_agent !~* ?', BotDetector::SQL_PATTERN)
    else
      clauses = BotDetector::LIKE_TERMS.map { "user_agent NOT LIKE ?" }.join(' AND ')
      where("user_agent IS NULL OR (#{clauses})", *BotDetector::LIKE_TERMS.map { |t| "%#{t}%" })
    end
  }

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
end
