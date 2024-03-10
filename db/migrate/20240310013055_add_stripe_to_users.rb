class AddStripeToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :stripe_customer_id, :string
    add_column :users, :subscription_status, :string

    # Optional: Adding indexes for quicker searches on these columns
    add_index :users, :stripe_customer_id
  end
end
