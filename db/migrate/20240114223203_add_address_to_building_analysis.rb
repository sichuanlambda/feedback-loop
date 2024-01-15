class AddAddressToBuildingAnalysis < ActiveRecord::Migration[7.1]
  def change
    add_column :building_analyses, :address, :string, default: "N/A"
  end
end
