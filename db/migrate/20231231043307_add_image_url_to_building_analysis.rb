class AddImageUrlToBuildingAnalysis < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :image_url, :string
  end
end
