module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "You don't have permission to access this area."
    end
  end
end 