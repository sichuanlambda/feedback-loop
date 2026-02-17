class CreatePlaceSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :place_subscriptions do |t|
      t.string :email, null: false
      t.integer :place_id, null: false
      t.datetime :subscribed_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :place_subscriptions, [:email, :place_id], unique: true
    add_index :place_subscriptions, :place_id
  end
end
