class PagesController < ApplicationController
  before_action :authenticate_user! # If you're using Devise
  def home
  end

  def account
    @user = current_user # This sets the @user variable to the currently logged in user
  end
end
