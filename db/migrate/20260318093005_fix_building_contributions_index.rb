class FixBuildingContributionsIndex < ActiveRecord::Migration[7.0]
  def up
    # Drop the problematic index if it exists (but not the table)
    if index_exists?(:building_contributions, :building_analysis_id, name: 'index_building_contributions_on_building_analysis_id')
      remove_index :building_contributions, name: 'index_building_contributions_on_building_analysis_id'
    end
    
    # Re-add with custom name to avoid conflicts
    unless index_exists?(:building_contributions, :building_analysis_id, name: 'idx_building_contributions_building_analysis')
      add_index :building_contributions, :building_analysis_id, name: 'idx_building_contributions_building_analysis'
    end
    
    # Add the remaining missing indexes if they don't exist
    unless index_exists?(:building_contributions, :contributed_at)
      add_index :building_contributions, :contributed_at
    end
    
    unless index_exists?(:building_contributions, :points_awarded)
      add_index :building_contributions, :points_awarded  
    end
  end

  def down
    # Clean up our custom index names
    if index_exists?(:building_contributions, :building_analysis_id, name: 'idx_building_contributions_building_analysis')
      remove_index :building_contributions, name: 'idx_building_contributions_building_analysis'
    end
  end
end