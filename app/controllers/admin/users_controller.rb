class Admin::UsersController < ApplicationController
  include AdminAuthorization
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.includes(:building_analyses, :screenshot_analyses)
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(20)
    
    if params[:search].present?
      search_term = params[:search].downcase
      @users = @users.where(
        "LOWER(email) LIKE ? OR LOWER(public_name) LIKE ? OR LOWER(handle) LIKE ?", 
        "%#{search_term}%", 
        "%#{search_term}%",
        "%#{search_term}%"
      )
    end

    if params[:admin_status].present?
      @users = @users.where(admin: params[:admin_status] == 'admin')
    end

    if params[:subscription_status].present?
      @users = @users.where(subscription_status: params[:subscription_status])
    end
  end

  def show
    @building_analyses = @user.building_analyses.order(created_at: :desc).limit(10)
    @screenshot_analyses = @user.screenshot_analyses.order(created_at: :desc).limit(10)
    @arch_images = []
    
    # User statistics
    @total_buildings = @user.building_analyses.count
    @visible_buildings = @user.building_analyses.where(visible_in_library: true).count
    @total_screenshots = @user.screenshot_analyses.count
    @total_generated_images = 0 # ArchImageGen doesn't have user association
    
    # Style frequency for this user
    @style_frequency = BuildingAnalysis.style_frequency(@user.id)
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: 'User was successfully deleted.'
  end

  def toggle_admin
    @user = User.find(params[:id])
    @user.update(admin: !@user.admin)
    
    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "Admin status updated for #{@user.email}." }
      format.json { render json: { admin: @user.admin } }
    end
  end

  def bulk_update
    user_ids = params[:user_ids]
    action = params[:bulk_action]

    if user_ids.present?
      case action
      when 'make_admin'
        User.where(id: user_ids).update_all(admin: true)
        notice = 'Selected users made admin.'
      when 'remove_admin'
        User.where(id: user_ids).update_all(admin: false)
        notice = 'Admin status removed from selected users.'
      when 'delete'
        User.where(id: user_ids).destroy_all
        notice = 'Selected users deleted.'
      when 'reset_credits'
        User.where(id: user_ids).update_all(credits: 5)
        notice = 'Credits reset for selected users.'
      end
    end

    redirect_to admin_users_path, notice: notice
  end

  def user_activity
    @user = User.find(params[:id])
    @activities = []
    
    # Combine all user activities
    @user.building_analyses.each do |building|
      @activities << {
        type: 'building_analysis',
        object: building,
        created_at: building.created_at,
        description: "Analyzed building ##{building.id}"
      }
    end
    
    @user.screenshot_analyses.each do |screenshot|
      @activities << {
        type: 'screenshot_analysis',
        object: screenshot,
        created_at: screenshot.created_at,
        description: "Analyzed screenshot ##{screenshot.id}"
      }
    end
    
    # Note: ArchImageGen doesn't have user association, so we'll skip this for now
    # ArchImageGen.where(user: @user).each do |image|
    #   @activities << {
    #     type: 'arch_image_gen',
    #     object: image,
    #     created_at: image.created_at,
    #     description: "Generated image ##{image.id}"
    #   }
    # end
    
    @activities.sort_by! { |activity| activity[:created_at] }.reverse!
    @activities = @activities.first(50) # Limit to 50 most recent activities
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :public_name, :handle, :bio, :profile_picture, 
                                :publicly_visible, :display_stats, :admin, :credits, 
                                :subscription_status, :stripe_customer_id)
  end
end
