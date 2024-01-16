class ApplicationController < ActionController::Base

  def account
    # Any specific logic for the account page (likely none for a static page)
  end

  private

  def after_sign_in_path_for(resource)
    # Specify the path you want to redirect users to after sign-in
    '/architecture_designer/step1'
  end

  def after_sign_out_path_for(resource_or_scope)
    # Specify the path you want to redirect users to after sign-out
    root_path
  end
end
#
