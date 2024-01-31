class AddProfileFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :handle, :string
    add_column :users, :public_name, :string
    add_column :users, :bio, :text
    add_column :users, :profile_picture, :string
    add_column :users, :publicly_visible, :boolean
    add_column :users, :display_stats, :boolean
  end
end
