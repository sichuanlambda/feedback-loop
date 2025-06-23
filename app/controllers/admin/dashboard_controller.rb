class Admin::DashboardController < ApplicationController
  include AdminAuthorization

  def index
    @total_buildings = BuildingAnalysis.count
    @visible_buildings = BuildingAnalysis.where(visible_in_library: true).count
    @hidden_buildings = BuildingAnalysis.where(visible_in_library: false).count
    @total_users = User.count
    @total_arch_images = ArchImageGen.count
    
    @recent_buildings = BuildingAnalysis.includes(:user).order(created_at: :desc).limit(5)
    @recent_users = User.order(created_at: :desc).limit(5)
    
    # Style statistics
    @style_counts = BuildingAnalysis.where(visible_in_library: true)
                                   .pluck(:h3_contents)
                                   .compact
                                   .flat_map { |content| JSON.parse(content) rescue [] }
                                   .tally
                                   .sort_by { |_, count| -count }
                                   .first(10)
  end
end
