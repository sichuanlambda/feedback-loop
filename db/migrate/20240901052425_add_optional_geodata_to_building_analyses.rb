class AddOptionalGeodataToBuildingAnalyses < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:building_analyses, :latitude)
      add_column :building_analyses, :latitude, :float, null: true
    end

    unless column_exists?(:building_analyses, :longitude)
      add_column :building_analyses, :longitude, :float, null: true
    end
  end
end
