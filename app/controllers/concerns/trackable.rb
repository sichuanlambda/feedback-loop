module Trackable
  extend ActiveSupport::Concern

  ATLAS_USER_ID = 880

  # The guest free-trial cap is enforced by looking these events up by IP, so
  # they are recorded even for scripted clients that the bot filter would skip.
  ALWAYS_TRACKED = %w[guest_analysis_started restyle_guest_started].freeze

  included do
    before_action :track_page_view
  end

  private

  def bot_request?
    return @bot_request if defined?(@bot_request)

    @bot_request = BotDetector.bot?(request.user_agent)
  end

  # Prefetches and service-worker precaches are GETs with a non-navigate
  # Sec-Fetch-Mode; real navigations say "navigate" (old clients send nothing).
  # POSTs (forms, the /api/events beacon) are never prefetches.
  def prefetch_request?
    mode = request.headers['Sec-Fetch-Mode']
    request.get? && mode.present? && mode != 'navigate'
  end

  def track_event(event_type, metadata = {})
    return if bot_request? && !ALWAYS_TRACKED.include?(event_type)
    return if prefetch_request?

    UserEvent.track(
      event_type: event_type,
      user: current_user,
      session_id: session.id.to_s.presence,
      request: request,
      metadata: metadata
    )
  end

  def track_page_view
    return if request.xhr? || !request.get? || bot_request?
    return if request.path.start_with?('/admin', '/api/', '/assets', '/rails')
    return if prefetch_request?

    UserEvent.track(
      event_type: 'page_view',
      user: current_user,
      session_id: session.id.to_s.presence,
      request: request,
      metadata: {
        path: request.path,
        referrer: request.referrer,
        params: request.query_parameters.except(:controller, :action).to_h.presence
      }.compact
    )
  end
end
