class CreateUserLevels < ActiveRecord::Migration[7.0]
  def change
    create_table :user_levels do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :level, default: 1
      t.integer :total_points, default: 0
      t.integer :buildings_analyzed, default: 0
      t.integer :styles_collected, default: 0
      t.integer :achievements_earned, default: 0
      t.datetime :last_activity_at
      t.datetime :level_reached_at, null: false

      t.timestamps
    end

    add_index :user_levels, :user_id, unique: true
    add_index :user_levels, :level
    add_index :user_levels, :total_points
    add_index :user_levels, :last_activity_at
  end
end