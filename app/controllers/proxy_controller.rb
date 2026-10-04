require 'net/http'
require 'uri'
require 'cgi'

class ProxyController < ApplicationController
  def fetch_street_view
    # radius is passed by the confirm step so the preview is the same photo
    # that will be analyzed (see StreetView.find)
    url = StreetView.image_url(params[:location].to_s, radius: params[:radius].presence)

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
    render plain: "Error fetching Street View image", status: :bad_gateway
  end
end
