class AddH3ContentsToBuildingAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :h3_contents, :text
  end
end
