class UsersController < ApplicationController
  def show
    @user = User.find_by(handle: params[:handle])

    # Redirect if the user does not exist or if the profile is not publicly visible
    unless @user && @user.publicly_visible
      return redirect_to root_path, alert: "Profile not found or is private."
    end

    # Retrieve the style frequency for the user
    style_frequency = BuildingAnalysis.style_frequency(@user.id)
    @style_frequency = style_frequency.sort_by { |style, frequency| -frequency }
    @unique_style_count = @style_frequency.length

    # Count the number of buildings analyzed/submitted by the user
    @buildings_submitted_count = BuildingAnalysis.where(user: @user).count

  end
end
