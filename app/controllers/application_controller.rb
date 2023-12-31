class ApplicationController < ActionController::Base
  private

  def after_sign_in_path_for(resource)
    # Specify the path you want to redirect users to after sign-in
    screenshot_searcher_path
  end

  def after_sign_out_path_for(resource_or_scope)
    # Specify the path you want to redirect users to after sign-out
    root_path
  end
end
