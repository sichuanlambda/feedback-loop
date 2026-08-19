class ApplicationController < ActionController::Base
  include Trackable

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_cache_headers
  before_action :expire_lapsed_subscription

  # Time-boxed paid access (e.g. a customer whose Stripe subscription is gone
  # but who paid through a date): downgrade automatically once the date passes.
  def expire_lapsed_subscription
    return unless user_signed_in?
    u = current_user
    if u.subscription_status == 'active' && u.subscription_expires_at.present? && u.subscription_expires_at.past?
      u.update_columns(subscription_status: 'inactive', subscription_expires_at: nil)
    end
  end

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

  # Attach a guest trial analysis to the account it just signed up for / into
  def claim_guest_analysis_for(user)
    analysis_id = session.delete(:guest_analysis_id)
    return if analysis_id.blank? || user.nil?

    analysis = BuildingAnalysis.find_by(id: analysis_id, user_id: User.guest.id)
    analysis&.update_columns(user_id: user.id, visible_in_library: true)
  end

  # Attach a guest trial restyle to the account it just signed up for / into
  def claim_guest_restyle_for(user)
    restyle_id = session.delete(:guest_restyle_id)
    return if restyle_id.blank? || user.nil?

    restyle = ArchImageGen.restyles.find_by(id: restyle_id, user_id: nil)
    restyle&.update_columns(user_id: user.id)
  end

  # One paid action for the signed-in user: free pass for active subscribers,
  # otherwise atomically spend one credit. Returns false when out of credits.
  def spend_generation_credit
    return true if current_user.subscription_status == 'active'

    User.where(id: current_user.id).where('credits > 0').update_all('credits = credits - 1').positive?
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation, :handle, :public_name, :marketing_opt_in, :terms_of_service])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email, :password, :password_confirmation, :current_password, :handle, :public_name, :marketing_opt_in])
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || '/architecture_designer/step1'
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
