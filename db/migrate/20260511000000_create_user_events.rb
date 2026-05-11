class CreateUserEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :user_events do |t|
      t.integer :user_id, null: true
      t.string :session_id
      t.string :event_type
      t.jsonb :metadata, default: {}
      t.string :ip_hash
      t.string :user_agent, null: true
      t.datetime :created_at, null: false
    end

    add_index :user_events, [:event_type, :created_at]
    add_index :user_events, [:user_id, :created_at]
    add_index :user_events, :session_id
    add_index :user_events, :created_at

    add_foreign_key :user_events, :users, on_delete: :nullify
  end
end
