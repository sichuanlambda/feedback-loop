module Api
  class BuildingAnalysesController < ApplicationController
    def index
      @building_analyses = BuildingAnalysis.all
      render json: @building_analyses.as_json(
        only: [:id, :address, :latitude, :longitude],
        methods: [:street_view_url]
      )
    end
  end
end
