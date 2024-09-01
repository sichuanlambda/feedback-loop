class EnsureGeodataColumnsAreNullable < ActiveRecord::Migration[6.1]
  def change
    change_column_null :building_analyses, :latitude, true
    change_column_null :building_analyses, :longitude, true
  end
end
