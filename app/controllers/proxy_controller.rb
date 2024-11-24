require 'net/http'
require 'uri'
require 'cgi'

class ProxyController < ApplicationController
  def fetch_street_view
    base_url = "https://maps.googleapis.com/maps/api/streetview"
    size = "600x400"
    location = params[:location] # Get the location parameter from the client request
    key = ENV['GOOGLE_MAPS_API_KEY']

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

  def fetch_satellite_view
    location = params[:location]
    api_key = Rails.application.credentials.google_maps[:api_key]

    # Add logging to debug
    Rails.logger.info "Location: #{location}"
    Rails.logger.info "API Key present: #{!api_key.nil?}"

    # Check if API key exists
    unless api_key
      Rails.logger.error "Google Maps API key is missing!"
      return render json: { error: 'API key not configured' }, status: :bad_request
    end

    zoom = "20"
    size = "600x600"
    maptype = "satellite"

    url = URI("https://maps.googleapis.com/maps/api/staticmap?" +
              "center=#{URI.encode_www_form_component(location)}" +
              "&zoom=#{zoom}" +
              "&size=#{size}" +
              "&maptype=#{maptype}" +
              "&key=#{api_key}")

    Rails.logger.info "Request URL: #{url}"

    begin
      response = Net::HTTP.get_response(url)
      Rails.logger.info "Response status: #{response.code}"

      if response.is_a?(Net::HTTPSuccess)
        send_data response.body, type: response.content_type, disposition: 'inline'
      else
        Rails.logger.error "API Error: #{response.body}"
        render json: { error: 'Failed to fetch satellite image' }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "Exception: #{e.message}"
      render json: { error: 'Failed to fetch satellite image' }, status: :bad_request
    end
  end
end
