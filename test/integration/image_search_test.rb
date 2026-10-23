require "test_helper"

class ImageSearchTest < ActionDispatch::IntegrationTest
  test "building photos describe the building, its style and city" do
    named = BuildingAnalysis.new(name: "Flatiron Building", city: "New York", h3_contents: ["Beaux-Arts", "Renaissance Revival"].to_json)
    assert_equal "Flatiron Building, New York: Beaux-Arts and Renaissance Revival architecture", named.image_alt

    unnamed = BuildingAnalysis.new(city: "Chicago", h3_contents: ["Art Deco"].to_json)
    assert_equal "Art Deco Building in Chicago", unnamed.image_alt, "an unnamed building already leads with its style"

    assert_equal "Flatiron Building", BuildingAnalysis.new(name: "Flatiron Building").image_alt
  end

  test "only real photos count as showable" do
    assert BuildingAnalysis.new(image_url: "https://bucket.s3.amazonaws.com/a.jpg").showable_image?
    refute BuildingAnalysis.new(image_url: "/proxy/fetch_street_view?location=x").showable_image?
    refute BuildingAnalysis.new(image_url: "https://screenshotsearcher.s3.amazonaws.com/a.png").showable_image?
  end

  test "blog heroes carry a Save to Pinterest link with the post, image and description" do
    BlogPost.create!(slug: "gothic-arches", title: "Gothic Arches", description: "How pointed arches work",
                     hero_image_url: "https://cdn.example.com/gothic.jpg", published: true, published_at: Time.current,
                     body_html: "<p>intro</p>")
    get blog_post_path(slug: "gothic-arches")

    link = css_select("a.pin-save").first
    assert link, "missing Pinterest link"
    query = Rack::Utils.parse_query(URI(link["href"]).query)
    assert_equal "http://www.example.com/blog/gothic-arches", query["url"]
    assert_equal "https://cdn.example.com/gothic.jpg", query["media"]
    assert_equal "How pointed arches work", query["description"]
    assert_select "script[src*='pinterest']", 0
  end

  test "the Pinterest domain claim tag renders only when configured" do
    get pricing_path
    assert_select "meta[name='p:domain_verify']", 0

    ENV["PINTEREST_DOMAIN_VERIFY"] = "abc123"
    get pricing_path
    assert_select "meta[name='p:domain_verify'][content=abc123]", 1
  ensure
    ENV.delete("PINTEREST_DOMAIN_VERIFY")
  end
end
