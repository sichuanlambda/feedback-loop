class AddVisibleInLibraryToBuildingAnalysis < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :visible_in_library, :boolean
  end
end
