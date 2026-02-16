class AddNameToBuildingAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :name, :string
  end
end
