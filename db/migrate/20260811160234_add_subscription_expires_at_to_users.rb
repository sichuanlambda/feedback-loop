class AddSubscriptionExpiresAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :subscription_expires_at, :datetime
  end
end
