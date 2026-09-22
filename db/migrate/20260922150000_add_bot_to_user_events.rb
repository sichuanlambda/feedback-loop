class AddBotToUserEvents < ActiveRecord::Migration[7.1]
  # Persisted crawler flag so reporting can filter with an index instead of a
  # regex over every row. Backfilled by `rake events:backfill_bot`; new rows are
  # classified on save (UserEvent#classify_agent).
  def change
    add_column :user_events, :bot, :boolean, default: false, null: false
    add_index :user_events, [:bot, :created_at]
  end
end
