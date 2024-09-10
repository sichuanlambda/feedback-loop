class AddCityToBuildingAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :city, :string
  end
end
