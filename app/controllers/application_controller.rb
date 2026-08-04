class ApplicationController < ActionController::Base
  include Trackable

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_cache_headers

  def set_cache_headers
    # Public pages get browser + CDN caching; user-specific pages stay private
    if user_signed_in?
      response.headers['Cache-Control'] = 'private, no-cache'
    elsif request.get? && !devise_controller?
      # 5 min browser cache, stale-while-revalidate for perceived speed
      expires_in 5.minutes, public: true, stale_while_revalidate: 1.day
    end
  end

  def account
    # Any specific logic for the account page (likely none for a static page)
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation, :handle, :public_name, :marketing_opt_in, :terms_of_service])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email, :password, :password_confirmation, :current_password, :handle, :public_name, :marketing_opt_in])
  end

  def after_sign_in_path_for(resource)
    # Specify the path you want to redirect users to after sign-in
    '/architecture_designer/step1'
  end

  def after_sign_out_path_for(resource_or_scope)
    # Specify the path you want to redirect users to after sign-out
    root_path
  end

  # Mobile app detection helpers
  def native_app?
    params[:native] == '1' || user_agent_native?
  end

  def user_agent_native?
    user_agent = request.user_agent.to_s.downcase
    user_agent.include?('architecture-helper') || 
    user_agent.include?('turbo-native') ||
    user_agent.include?('ah-mobile')
  end

  def mobile_browser?
    request.user_agent.to_s.match(/(Mobile|webOS|rv:1.1|Opera Mini|Android|BlackBerry|iPhone|iPad)/)
  end

  # Gamification helpers
  def check_and_notify_achievements(trigger = nil)
    return unless user_signed_in?
    
    newly_earned = AchievementCheckingService.check_achievements(current_user, trigger)
    
    if newly_earned.any?
      @achievement_notifications = newly_earned.map do |achievement|
        metadata = JSON.parse(achievement.metadata)
        {
          name: metadata['name'],
          description: metadata['description'],
          icon: metadata['icon'],
          category: metadata['category'],
          points: metadata['points'],
          badge_count: achievement.badge_count
        }
      end
    end

    # Check for level up (safe: use total_points instead of missing points_required column)
    begin
      current_level = current_user.user_level
      if current_level && current_level.updated_at > 5.minutes.ago
        pts = current_level.total_points || 0
        @level_up_notification = {
          level: current_level.level,
          points_required: pts,
          previous_points: [pts - 100, 0].max,
          badge_count: current_user.user_achievements.sum(:badge_count)
        }
      end
    rescue => e
      Rails.logger.warn("Level check skipped: #{e.message}")
    end
  end

  helper_method :native_app?, :mobile_browser?
end
