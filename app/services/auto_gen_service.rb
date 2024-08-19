# app/services/auto_gen_service.rb

require 'net/http'
require 'uri'
require 'json'

class AutoGenService
  def initialize
    @base_url = 'http://127.0.0.1:5000'  # Python Flask server URL
  end

  def generate_search_results(query)
    uri = URI.parse("#{@base_url}/ask")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request.body = { input: query }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      raise "Error: #{response.message}"
    end

    # Debugging: Print out details
    puts "Request URL: #{uri}"
    puts "Response Code: #{response.code}"
    puts "Response Message: #{response.message}"
    puts "Response Body: #{response.body}"

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      raise "Error: #{response.message}"
    end
  end

end
