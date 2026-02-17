class AddMarketingOptInToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :marketing_opt_in, :boolean, default: false, null: false
    add_column :users, :marketing_opted_in_at, :datetime
  end
end
