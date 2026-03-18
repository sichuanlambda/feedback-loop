class CreateUserStyleCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :user_style_collections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :style_name, null: false
      t.integer :building_count, default: 0
      t.datetime :first_collected_at, null: false
      t.datetime :last_updated_at, null: false
      t.json :building_ids # Array of building_analysis ids for this style

      t.timestamps
    end

    add_index :user_style_collections, [:user_id, :style_name], unique: true
    add_index :user_style_collections, :style_name
    add_index :user_style_collections, :building_count
  end
end