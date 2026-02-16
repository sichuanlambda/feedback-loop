class Admin::BuildingAnalysesController < ApplicationController
  include AdminAuthorization
  before_action :set_building_analysis, only: [:show, :edit, :update, :destroy]

  def index
    @building_analyses = BuildingAnalysis.includes(:user)
                                        .order(created_at: :desc)
                                        .page(params[:page])
                                        .per(20)
    
    if params[:search].present?
      search_term = params[:search].downcase
      @building_analyses = @building_analyses.where(
        "LOWER(h3_contents) LIKE ? OR LOWER(address) LIKE ?", 
        "%#{search_term}%", 
        "%#{search_term}%"
      )
    end

    if params[:visibility].present?
      @building_analyses = @building_analyses.where(visible_in_library: params[:visibility] == 'visible')
    end
  end

  def show
  end

  def edit
  end

  def update
    if @building_analysis.update(building_analysis_params)
      redirect_to admin_building_analysis_path(@building_analysis), notice: 'Building analysis was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @building_analysis.destroy
    redirect_to admin_building_analyses_path, notice: 'Building analysis was successfully deleted.'
  end

  def toggle_visibility
    @building_analysis = BuildingAnalysis.find(params[:id])
    @building_analysis.update(visible_in_library: !@building_analysis.visible_in_library)
    
    respond_to do |format|
      format.html { redirect_to admin_building_analyses_path, notice: 'Visibility updated successfully.' }
      format.json { render json: { visible: @building_analysis.visible_in_library } }
    end
  end

  def bulk_import
    unless params[:buildings].is_a?(Array)
      return render json: { error: "Expected 'buildings' array" }, status: :unprocessable_entity
    end

    results = []
    params[:buildings].each do |building_params|
      ba = BuildingAnalysis.create!(
        user: current_user,
        address: building_params[:address],
        name: building_params[:name],
        image_url: building_params[:image_url],
        visible_in_library: true
      )

      if building_params[:image_url].present?
        ProcessBuildingAnalysisJob.perform_later(ba.id, building_params[:image_url], building_params[:address])
      end

      results << { id: ba.id, address: ba.address, name: ba.name, status: 'queued' }
    end

    render json: { imported: results.length, buildings: results }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def bulk_update
    building_analysis_ids = params[:building_analysis_ids]
    action = params[:bulk_action]

    if building_analysis_ids.present?
      case action
      when 'make_visible'
        BuildingAnalysis.where(id: building_analysis_ids).update_all(visible_in_library: true)
        notice = 'Selected buildings made visible in library.'
      when 'make_hidden'
        BuildingAnalysis.where(id: building_analysis_ids).update_all(visible_in_library: false)
        notice = 'Selected buildings hidden from library.'
      when 'delete'
        BuildingAnalysis.where(id: building_analysis_ids).destroy_all
        notice = 'Selected buildings deleted.'
      end
    end

    redirect_to admin_building_analyses_path, notice: notice
  end

  private

  def set_building_analysis
    @building_analysis = BuildingAnalysis.find(params[:id])
  end

  def building_analysis_params
    params.require(:building_analysis).permit(:image_url, :h3_contents, :html_content, :visible_in_library, :address, :city, :name)
  end
end
