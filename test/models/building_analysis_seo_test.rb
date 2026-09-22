require "test_helper"

class BuildingAnalysisSeoTest < ActiveSupport::TestCase
  test "named building uses its name and city" do
    assert_equal "Chrysler Building, New York City — Architecture Analysis", building_analyses(:one).seo_title
  end

  test "structured name wins over the stored name" do
    assert_equal "Lever House, New York City — Architecture Analysis", building_analyses(:one).seo_title("Lever House")
  end

  test "unnamed building is described by its top styles and city" do
    assert_equal "Art Deco & Gothic Revival Building in Chicago — Architecture Analysis", building_analyses(:two).seo_title
  end

  test "placeholder names count as unnamed" do
    building = building_analyses(:two)
    ["Building Analysis", "Building", "N/A", "null"].each do |placeholder|
      building.name = placeholder
      assert_match(/\AArt Deco & Gothic Revival Building in Chicago/, building.seo_title, placeholder)
    end
  end

  test "a building with no styles or city stays unique via its id" do
    building = BuildingAnalysis.new(id: 42)
    assert_equal "Building #42 — Architecture Analysis", building.seo_title
  end

  test "city is not repeated when the name already contains it" do
    building = building_analyses(:one)
    building.name = "Chicago Board of Trade"
    building.city = "Chicago"
    assert_equal "Chicago Board of Trade — Architecture Analysis", building.seo_title
  end

  test "description prefers the overview and otherwise mentions styles" do
    assert_equal "A short overview.", building_analyses(:two).seo_description("A short overview.")
    description = building_analyses(:two).seo_description
    assert_includes description, "Art Deco, Gothic Revival, and Modernism"
    assert_operator description.length, :<=, 155
    refute_includes description, "Building Analysis"
  end

  test "style_names tolerates bad json" do
    assert_equal [], BuildingAnalysis.new(h3_contents: "not json").style_names
  end
end
