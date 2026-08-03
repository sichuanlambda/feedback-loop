class CreateUserAchievements < ActiveRecord::Migration[7.0]
  def change
    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :achievement_key, null: false
      t.datetime :earned_at, null: false
      t.integer :badge_count, default: 1
      t.text :metadata # Store extra data like specific styles, counts, etc.

      t.timestamps
    end

    add_index :user_achievements, [:user_id, :achievement_key], unique: true
    add_index :user_achievements, :achievement_key
    add_index :user_achievements, :earned_at
  end
end