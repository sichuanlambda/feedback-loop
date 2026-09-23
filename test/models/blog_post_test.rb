require "test_helper"

class BlogPostTest < ActiveSupport::TestCase
  def post(**attrs)
    BlogPost.create!({ slug: "dated-post", title: "Dated Post", body_html: "<p>x</p>", published_at: 40.days.ago }.merge(attrs))
  end

  test "a hero image or CTA change does not count as a content update" do
    p = post
    p.update_columns(hero_image_url: "https://example.com/h.png", cta_category: "styles", updated_at: Time.current)
    p.reload
    assert_equal p.published_at.to_i, p.content_modified_at.to_i
    refute p.content_revised?
  end

  test "a text change is shown as an update" do
    p = post(content_updated_at: 2.days.ago)
    assert p.content_revised?
    assert_equal 2.days.ago.to_date, p.content_modified_at.to_date
  end

  test "a post revised the day it was published is not marked updated" do
    p = post(published_at: 1.day.ago, content_updated_at: Time.current)
    refute p.content_revised?
  end
end
