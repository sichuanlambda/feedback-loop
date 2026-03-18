class GamificationSchemaFix < ActiveRecord::Migration[7.0]
  def up
    # Ensure user_levels table exists
    unless table_exists?(:user_levels)
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
    end

    # Add indexes for user_levels if they don't exist
    unless index_exists?(:user_levels, :user_id, unique: true)
      add_index :user_levels, :user_id, unique: true
    end
    
    unless index_exists?(:user_levels, :level)
      add_index :user_levels, :level
    end
    
    unless index_exists?(:user_levels, :total_points)
      add_index :user_levels, :total_points
    end
    
    unless index_exists?(:user_levels, :last_activity_at)
      add_index :user_levels, :last_activity_at
    end
    
    # Fix building_contributions indexes
    if table_exists?(:building_contributions)
      # Add missing indexes if they don't exist
      unless index_exists?(:building_contributions, :contributed_at)
        add_index :building_contributions, :contributed_at
      end
      
      unless index_exists?(:building_contributions, :points_awarded)
        add_index :building_contributions, :points_awarded
      end
    end

    # Mark the problematic migrations as completed
    execute "INSERT INTO schema_migrations (version) VALUES ('20260318093004') ON CONFLICT DO NOTHING"
    execute "INSERT INTO schema_migrations (version) VALUES ('20260318093005') ON CONFLICT DO NOTHING"
  end

  def down
    # Remove the version entries if rolling back
    execute "DELETE FROM schema_migrations WHERE version IN ('20260318093004', '20260318093005')"
  end
end