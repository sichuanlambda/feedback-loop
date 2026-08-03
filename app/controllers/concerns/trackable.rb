module Trackable
  extend ActiveSupport::Concern

  ATLAS_USER_ID = 880

  included do
    before_action :track_page_view
  end

  private

  def track_event(event_type, metadata = {})
    UserEvent.track(
      event_type: event_type,
      user: current_user,
      session_id: session.id.to_s,
      request: request,
      metadata: metadata
    )
  end

  def track_page_view
    return if request.xhr? || !request.get?
    return if request.path.start_with?('/admin', '/api/', '/assets', '/rails')

    UserEvent.track(
      event_type: 'page_view',
      user: current_user,
      session_id: session.id.to_s,
      request: request,
      metadata: {
        path: request.path,
        referrer: request.referrer,
        params: request.query_parameters.except(:controller, :action).to_h.presence
      }.compact
    )
  end
end
