module Trackable
  extend ActiveSupport::Concern

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
end
