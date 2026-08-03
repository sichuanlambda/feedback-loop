class CreateBuildingContributions < ActiveRecord::Migration[7.0]
  def change
    create_table :building_contributions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building_analysis, null: false, foreign_key: true
      t.string :contribution_type, null: false # 'submission', 'analysis', 'photo', etc.
      t.integer :points_awarded, default: 0
      t.datetime :contributed_at, null: false
      t.text :description
      t.json :metadata

      t.timestamps
    end

    add_index :building_contributions, [:user_id, :contribution_type]
    add_index :building_contributions, :building_analysis_id, name: 'idx_building_contributions_building_analysis_alt'
    add_index :building_contributions, :contributed_at
    add_index :building_contributions, :points_awarded
  end
end