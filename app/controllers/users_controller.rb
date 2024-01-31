class UsersController < ApplicationController
  def show
    @user = User.find_by(handle: params[:handle])
    unless @user && @user.publicly_visible
      redirect_to root_path, alert: "Profile not found or is private."
    end
  end
end
