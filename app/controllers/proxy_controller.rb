require 'net/http'
require 'uri'
require 'cgi'

class ProxyController < ApplicationController
  def fetch_street_view
    base_url = "https://maps.googleapis.com/maps/api/streetview"
    size = "600x400"
    location = params[:location] # Get the location parameter from the client request
    key = Rails.application.credentials.google_maps[:api_key] # Securely use your API key

    # Correctly encode the location parameter
    encoded_location = CGI.escape(location)

    # Construct the URL with query parameters
    url = "#{base_url}?size=#{size}&location=#{encoded_location}&key=#{key}"

    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    Rails.logger.info "Street View API Response Status: #{response.code}" # Log the response status

    if response.is_a?(Net::HTTPSuccess)
      send_data response.body, type: 'image/jpeg', disposition: 'inline'
    else
      Rails.logger.error "Street View API Error: #{response.body}" # Log error response
      render plain: "Error fetching Street View image: #{response.message}", status: :bad_request
    end
  rescue => e
    Rails.logger.error "Street View API Exception: #{e.message}" # Log any exceptions
    render plai
  end
end
