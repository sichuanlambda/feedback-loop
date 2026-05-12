class Api::EventsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def create
    # Simple rate limiting - skip if no session to prevent abuse
    unless session.id.present?
      head :ok
      return
    end
    
    track_event(
      params[:event_type],
      (params[:metadata] || {}).to_unsafe_h.merge(client_side: true)
    )
    head :ok
  rescue => e
    Rails.logger.error "Client-side event tracking failed: #{e.message}"
    head :ok # Always return success to avoid breaking client-side code
  end
end