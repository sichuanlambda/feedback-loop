class AddMarketingOptInToUsers < ActiveRecord::Migration[7.1]
  def change
    # Production already gained these columns from an earlier deploy
    unless column_exists?(:users, :marketing_opt_in)
      add_column :users, :marketing_opt_in, :boolean, default: false, null: false
    end
    unless column_exists?(:users, :marketing_opted_in_at)
      add_column :users, :marketing_opted_in_at, :datetime
    end
  end
end
