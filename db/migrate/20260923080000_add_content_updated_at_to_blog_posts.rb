class AddContentUpdatedAtToBlogPosts < ActiveRecord::Migration[7.1]
  # When the post's text last changed. updated_at also moves for hero images,
  # CTA classification and link normalization, which readers and search
  # engines should not see as "updated". Backfilled from updated_at, which was
  # corrected by hand on 2026-09-23.
  def up
    add_column :blog_posts, :content_updated_at, :datetime
    execute "UPDATE blog_posts SET content_updated_at = updated_at"
  end

  def down
    remove_column :blog_posts, :content_updated_at
  end
end
