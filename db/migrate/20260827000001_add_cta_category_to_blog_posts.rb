class AddCtaCategoryToBlogPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :blog_posts, :cta_category, :string
    add_index :blog_posts, :cta_category
  end
end
