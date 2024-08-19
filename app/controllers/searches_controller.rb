class SearchesController < ApplicationController

  def create
    @query = params[:query]
    service = AutoGenService.new

    begin
      @results = service.generate_search_results(@query)
    rescue => e
      @error = "Search failed: #{e.message}"
    end

    render :new
  end
end
