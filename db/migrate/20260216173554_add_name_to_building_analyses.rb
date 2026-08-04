class AddNameToBuildingAnalyses < ActiveRecord::Migration[7.1]
  def change
    # Production already gained this column from an earlier deploy
    add_column :building_analyses, :name, :string unless column_exists?(:building_analyses, :name)
  end
end
