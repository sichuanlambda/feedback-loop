class AddUserToBuildingAnalysis < ActiveRecord::Migration[6.0]
  def up
    # Add the user reference but allow nulls temporarily
    add_reference :building_analyses, :user, null: true, foreign_key: true

    # Set a default user_id here. Replace `default_user_id` with the actual ID
    default_user_id = 1 # or the ID of your system user
    BuildingAnalysis.update_all(user_id: default_user_id)

    # Change the column to not allow nulls
    change_column_null :building_analyses, :user_id, false
  end

  def down
    remove_reference :building_analyses, :user
  end
end
