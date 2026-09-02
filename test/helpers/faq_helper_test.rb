require "test_helper"

class FaqHelperTest < ActionView::TestCase
  # The app's fixtures are stale (screenshot_analyses.yml); these tests build their own rows.
  self.fixture_table_names = []

  include ApplicationHelper

  test "faq_structured_data emits FAQPage json-ld with plain-text answers" do
    html = faq_structured_data([{ "question" => "What is it?", "answer" => "<p>An <strong>answer</strong>.</p>" },
                                { question: "", answer: "dropped" }])
    data = JSON.parse(html[/\{.*\}/m])
    assert_equal "FAQPage", data["@type"]
    assert_equal 1, data["mainEntity"].size
    assert_equal "An answer.", data["mainEntity"][0]["acceptedAnswer"]["text"]
  end

  test "faq_structured_data is empty for no usable items" do
    assert_equal "", faq_structured_data([])
    assert_equal "", faq_structured_data(nil)
  end

  test "building_default_faqs needs at least two facts" do
    b = BuildingAnalysis.new(address: "N/A")
    assert_equal [], building_default_faqs(b, { "styles" => [{ "name" => "Art Deco" }] })
    faqs = building_default_faqs(b, { "building_name" => "X", "styles" => [{ "name" => "Art Deco", "confidence" => 90 }], "year_built" => "1930" })
    assert_equal 2, faqs.size
    assert_match(/Art Deco architecture \(90% confidence\)/, faqs[0][:answer])
  end
end
