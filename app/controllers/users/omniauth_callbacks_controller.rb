class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def passthru
    Rails.logger.info "OmniAuth passthru called with env: #{request.env['omniauth.auth']}"
    super
  end

  def google_oauth2
    Rails.logger.info "Google OAuth2 callback received with env: #{request.env['omniauth.auth']}"
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.persisted?
      claim_guest_analysis_for(@user)
      claim_guest_restyle_for(@user)
      if @user.previously_new_record?
        track_event('user_signup', { user_id: @user.id, provider: 'google_oauth2' })
        # Same first stop as email signups: the upload form their free credit is for
        store_location_for(@user, architecture_explorer_new_path(src: 'post_signup')) if session[:user_return_to].blank?
      end
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra") # Removing extra as it can overflow some session stores
      redirect_to new_user_session_path, alert: 'Could not authenticate you from Google OAuth2 because "User info could not be retrieved".'
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "Authentication failed, please try again."
  end
end
