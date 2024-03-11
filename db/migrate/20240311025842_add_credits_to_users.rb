class AddCreditsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :credits, :integer, default: 0, null: false
  end
end
