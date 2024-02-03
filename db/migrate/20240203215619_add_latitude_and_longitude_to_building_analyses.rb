class AddLatitudeAndLongitudeToBuildingAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :latitude, :float
    add_column :building_analyses, :longitude, :float
  end
end
