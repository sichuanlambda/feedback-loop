class CreateBuildingAnalyses < ActiveRecord::Migration[6.0]
  def change
    create_table :building_analyses do |t|
      t.json :key_influences
      t.json :key_characteristics
      t.text :details

      t.timestamps
    end
  end
end
