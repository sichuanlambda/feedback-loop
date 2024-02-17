# frozen_string_literal: true

Devise.setup do |config|
  # Existing Devise configurations...
  config.mailer_sender = 'nathaninproduct@gmail.com'
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :get
  config.responder.error_status = :unprocessable_entity
  config.responder.redirect_status = :see_other

  require 'devise/orm/active_record'

  # OmniAuth Google OAuth2 configuration
  config.omniauth :google_oauth2,
  Rails.application.credentials.dig(:google_oauth, :client_id),
  Rails.application.credentials.dig(:google_oauth, :client_secret), {
    scope: 'userinfo.email,userinfo.profile',
    prompt: 'select_account',
    image_aspect_ratio: 'square',
    image_size: 50
}
end
