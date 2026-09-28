class UserEvent < ApplicationRecord
  belongs_to :user, optional: true

  scope :recent, -> { where(created_at: 30.days.ago..) }
  scope :by_type, ->(t) { where(event_type: t) }

  before_save :classify_agent

  # Real-visitor rows. Crawlers are flagged on save (and were backfilled with
  # `rake events:backfill_bot`); server-originated rows have no agent and count.
  scope :human, -> { where(bot: false) }

  # Crawlers that keep cookies look like people until you notice they load
  # three or more different pages in the same second and never run the JS
  # beacon. Flags every row of such sessions; safe to re-run (idempotent).
  def self.flag_parallel_crawlers!(since: 3.days.ago)
    second = if connection.adapter_name.match?(/postg/i)
               "date_trunc('second', created_at)"
             else
               "strftime('%Y-%m-%d %H:%M:%S', created_at)"
             end
    path = connection.adapter_name.match?(/postg/i) ? "metadata->>'path'" : "json_extract(metadata, '$.path')"

    suspects = where(event_type: 'page_view').where('created_at >= ?', since).where.not(session_id: [nil, ''])
                 .group(:session_id, Arel.sql(second)).having("COUNT(DISTINCT #{path}) >= 3").pluck(:session_id).uniq
    return 0 if suspects.empty?

    engaged = where(event_type: 'js_pageview', session_id: suspects).where('created_at >= ?', since - 1.day).distinct.pluck(:session_id)
    crawlers = suspects - engaged
    return 0 if crawlers.empty?

    where(session_id: crawlers, bot: false).where('created_at >= ?', since - 1.day).update_all(bot: true)
  end

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
