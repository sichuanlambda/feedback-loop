class ArchitectureDesignerController < ApplicationController
  before_action :set_custom_nav

  def step1
    @latest_images = ArchImageGen.order(created_at: :desc).limit(5)
    Rails.logger.debug "Latest Images: #{@latest_images}"
    # other code...
  end
  def step2
    # Store the user's selection from Step 1 in the session
    session[:architecture_type] = params[:selected_option]
    # ... rest of the step2 action ...
  end

  def step3
    # Assuming Step 2 selections are passed here
    session[:step2_selections] = params[:user_selections]
    # ... rest of the step3 action ...
  end

  private

  def set_custom_nav
    @custom_nav = true
  end

end
