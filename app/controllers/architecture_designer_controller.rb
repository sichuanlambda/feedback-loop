class ArchitectureDesignerController < ApplicationController
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
end
