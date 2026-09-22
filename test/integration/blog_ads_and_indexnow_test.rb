require "test_helper"

class BlogAdsAndIndexnowTest < ActionDispatch::IntegrationTest
  def two_section_post
    BlogPost.create!(slug: "test-post", title: "Test Post", published: true, published_at: Time.current,
                     body_html: "<p>intro</p><h2>One</h2><p>a</p><h2>Two</h2><p>b</p>")
  end

  test "blog posts load TinyAdz and place an ad slot after each CTA" do
    post = two_section_post
    get blog_post_path(slug: post.slug)

    assert_response :success
    # Outside production the script runs in demo mode so localhost never serves live ads
    assert_select "script[src='https://cdn.apitiny.net/scripts/v2.0/main.js'][data-site-id='680224994f403e3470159cfa'][data-test-mode='true']", 1
    assert_select "div.post-ad[ta-ad-container]", 2

    body = response.body
    first_cta = body.index('class="post-cta"')
    first_ad = body.index("ta-ad-container")
    assert_operator first_cta, :<, first_ad, "the ad slot must come after the CTA, not before it"
  end

  test "product pages stay ad-free" do
    [architecture_explorer_new_path, pricing_path, "/building_library",
     architecture_explorer_show_path(building_analyses(:one)), new_user_registration_path].each do |path|
      get path
      assert_response :success, path
      assert_select "script[src*='apitiny']", 0, path
      assert_select "[ta-ad-container]", 0, path
    end
  end

  test "indexnow key file serves the configured key and 404s without one" do
    original = ENV["INDEXNOW_KEY"]
    ENV["INDEXNOW_KEY"] = "abc123def456"
    get "/indexnow-key.txt"
    assert_response :success
    assert_equal "abc123def456", response.body
    assert_match %r{text/plain}, response.content_type

    ENV["INDEXNOW_KEY"] = nil
    get "/indexnow-key.txt"
    assert_response :not_found
  ensure
    ENV["INDEXNOW_KEY"] = original
  end
end
