class CreateBlogPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :blog_posts do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :description
      t.text :body_html
      t.string :hero_image_url
      t.datetime :published_at
      t.boolean :published, default: true, null: false

      t.timestamps
    end
    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published_at
  end
end
