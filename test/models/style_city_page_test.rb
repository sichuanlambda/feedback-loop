require "test_helper"

class StyleCityPageTest < ActiveSupport::TestCase
  # The app's fixtures are stale (screenshot_analyses.yml); these tests build their own rows.
  self.fixture_table_names = []

  setup do
    Rails.cache.clear
    @user = User.first || User.create!(email: "scp-test@example.com", password: "password123")
    { "Kraków" => 4, "Denver" => 2 }.each do |city, n|
      n.times do |i|
        BuildingAnalysis.create!(user: @user, visible_in_library: true, city: city,
                                 address: "#{i} Test St, #{city}", h3_contents: ["Gothic 80%", "Victorian 20%"].to_json)
      end
    end
  end

  test "pair_counts tallies canonical styles per city" do
    counts = StyleCityPage.pair_counts
    assert_equal 4, counts[["Gothic", "Kraków"]]
    assert_equal 4, counts[["Victorian", "Kraków"]]
    assert_equal 2, counts[["Gothic", "Denver"]]
  end

  test "indexable_pairs applies the minimum" do
    pairs = StyleCityPage.indexable_pairs
    assert_includes pairs.keys, ["Gothic", "Kraków"]
    refute_includes pairs.keys, ["Gothic", "Denver"]
  end

  test "resolve_city maps an ascii slug back to the stored city" do
    assert_equal "Kraków", StyleCityPage.resolve_city("krakow")
    assert_nil StyleCityPage.resolve_city("nowhereville")
  end

  test "path_for builds the public url" do
    assert_equal "/styles/art-deco/in/den-haag", StyleCityPage.path_for("Art Deco", "Den Haag")
  end

  test "uniqueness of style + city" do
    StyleCityPage.create!(style_name: "Gothic", city_slug: "krakow", city_name: "Kraków")
    dup = StyleCityPage.new(style_name: "Gothic", city_slug: "krakow", city_name: "Kraków")
    refute dup.valid?
  end
end
