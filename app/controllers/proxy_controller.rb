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

    # Make the HTTP request to Google Maps API
    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    # Forward the response to the client
    if response.is_a?(Net::HTTPSuccess)
      send_data response.body, type: 'image/jpeg', disposition: 'inline'
    else
      # Handle error (e.g., location not found or API key issue)
      render plain: "Error fetching Street View image", status: :bad_request
    end
  end
end
