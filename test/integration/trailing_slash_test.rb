require "test_helper"

class TrailingSlashTest < ActionDispatch::IntegrationTest
  test "trailing-slash URLs redirect permanently to the canonical path" do
    get "/pricing/"
    assert_response :moved_permanently
    assert_redirected_to "/pricing"

    get "/architecture_explorer/#{building_analyses(:one).id}/"
    assert_response :moved_permanently
    assert_redirected_to "/architecture_explorer/#{building_analyses(:one).id}"
  end

  test "the query string survives the redirect" do
    get "/blog/?page=2"
    assert_response :moved_permanently
    assert_redirected_to "/blog?page=2"
  end

  test "the root and slash-less pages are untouched, and canonicals match the URL served" do
    get "/"
    assert_response :success

    get "/pricing"
    assert_response :success
    assert_select "link[rel=canonical][href='http://www.example.com/pricing']"
  end

  test "the redirect is not recorded as a pageview" do
    assert_no_difference -> { UserEvent.count } do
      get "/pricing/", headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) Safari/604.1" }
    end
  end
end
