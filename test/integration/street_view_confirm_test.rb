require "test_helper"
require "minitest/mock"

# An address-only analysis shows the Street View photo for confirmation first,
# and never runs on Google's grey "no imagery here" placeholder.
class StreetViewConfirmTest < ActionDispatch::IntegrationTest
  CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36".freeze
  ADDRESS = "Lincoln Memorial, Washington DC".freeze

  def visit_with_address(found)
    StreetView.stub(:find, found) do
      get architecture_explorer_new_path(address: ADDRESS, src: "blog_tryit"), headers: { "User-Agent" => CHROME }
    end
    assert_response :success
  end

  test "an address with a Street View photo asks for confirmation before analyzing" do
    visit_with_address({ radius: 150 })

    assert_select "#street-view-confirm" do
      assert_select "img[src$='location=Lincoln+Memorial%2C+Washington+DC&radius=150']", 1
      assert_select "form[action='#{architecture_explorer_path}'][method=post]", 1 do
        assert_select "input[name=address][value='#{ADDRESS}']", 1
        assert_select "input[name=confirmed][value='1']", 1
        assert_select "input[name=src][value=blog_tryit]", 1
        assert_select "input[name=fg_ts]", 1
      end
    end
    assert_select "#street-view-missing", 0
    assert_equal({ "src" => "blog_tryit", "street_view" => "found" }, UserEvent.where(event_type: "building_new_form").last.metadata)
  end

  test "an address without a Street View photo says so and keeps the address for correction" do
    visit_with_address(nil)

    assert_select "#street-view-confirm", 0
    assert_select "#street-view-missing", text: /couldn't find a street-level photo/
    assert_select "input#address-field[value='#{ADDRESS}']", 1
    assert_equal "missing", UserEvent.where(event_type: "building_new_form").last.metadata["street_view"]
  end

  test "the upload page without an address is unchanged" do
    get architecture_explorer_new_path, headers: { "User-Agent" => CHROME }

    assert_select "#street-view-confirm, #street-view-missing", 0
    assert_equal({}, UserEvent.where(event_type: "building_new_form").last.metadata)
  end

  test "an address-only submission goes to the confirm step instead of being analyzed" do
    [{}, { confirmed: "1" }, human_form.merge(confirmed: "1", subject_line: "x")].each do |extra|
      assert_no_difference "BuildingAnalysis.count" do
        StreetView.stub(:find, { radius: nil }) do
          post architecture_explorer_path, params: { address: ADDRESS, src: "blog_tryit" }.merge(extra)
        end
      end
      assert_redirected_to architecture_explorer_new_path(address: ADDRESS, src: "blog_tryit")
    end
  end

  test "a confirmed address with no Street View photo is not analyzed" do
    assert_no_difference "BuildingAnalysis.count" do
      StreetView.stub(:find, nil) do
        post architecture_explorer_path, params: human_form.merge(address: "943 Bivium Circle", confirmed: "1")
      end
    end
    assert_redirected_to architecture_explorer_new_path(address: "943 Bivium Circle")
  end

  test "lookup widens the radius, reports no imagery, and fails open" do
    answers = ['{"status":"ZERO_RESULTS"}', '{"status":"OK"}']
    opened = []
    fake_open = ->(url, **) { opened << url; StringIO.new(answers.shift) }
    URI.stub(:open, fake_open) { assert_equal({ radius: 150 }, StreetView.find(ADDRESS)) }
    assert_equal 2, opened.size
    refute_includes opened.first, "radius="
    assert_includes opened.last, "radius=150"

    URI.stub(:open, ->(*, **) { StringIO.new('{"status":"ZERO_RESULTS"}') }) { assert_nil StreetView.find(ADDRESS) }
    URI.stub(:open, ->(*, **) { raise Net::OpenTimeout }) { assert_equal({ radius: nil }, StreetView.find(ADDRESS)) }
    assert_nil StreetView.find("")
  end
end
