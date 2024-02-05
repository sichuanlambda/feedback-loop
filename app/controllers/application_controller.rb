class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  def account
    # Any specific logic for the account page (likely none for a static page)
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation, :handle, :public_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email, :password, :password_confirmation, :current_password, :handle, :public_name])
  end

  def after_sign_in_path_for(resource)
    # Specify the path you want to redirect users to after sign-in
    '/architecture_designer/step1'
  end

  def after_sign_out_path_for(resource_or_scope)
    # Specify the path you want to redirect users to after sign-out
    root_path
  end
end
