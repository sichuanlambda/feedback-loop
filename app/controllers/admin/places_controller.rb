class Admin::PlacesController < ApplicationController
  include AdminAuthorization
  before_action :set_place, only: [:show, :edit, :update, :destroy]

  def index
    @places = Place.order(:name)
  end

  def show
  end

  def new
    @place = Place.new
  end

  def edit
  end

  def create
    @place = Place.new(place_params)

    if @place.save
      redirect_to admin_place_path(@place), notice: 'Place was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @place.update(place_params)
      redirect_to admin_place_path(@place), notice: 'Place was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @place.destroy
    redirect_to admin_places_path, notice: 'Place was successfully deleted.'
  end

  private

  def set_place
    @place = Place.find(params[:id])
  end

  def place_params
    params.require(:place).permit(:name, :slug, :latitude, :longitude, :zoom_level, 
                                 :description, :content, :published, :featured, 
                                 :meta_title, :meta_description)
  end
end 