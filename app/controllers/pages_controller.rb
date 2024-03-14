class PagesController < ApplicationController
  before_action :authenticate_user! # If you're using Devise
  before_action :set_user_stats, only: [:account]

  def home
  end

  def account
    @user = current_user
    # Any other setup needed for the account page can be added here
  end

  private

  def set_user_stats
    return unless user_signed_in?

    style_frequency = BuildingAnalysis.style_frequency(current_user.id)
    @style_frequency = style_frequency.to_a.sort_by { |_, frequency| -frequency }.first(5)
    @unique_style_count = style_frequency.length
    @buildings_submitted_count = BuildingAnalysis.where(user: current_user).count
  end
end
