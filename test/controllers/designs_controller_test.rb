require "test_helper"

class DesignsControllerTest < ActionDispatch::IntegrationTest
  test "should get submit" do
    get designs_submit_url
    assert_response :success
  end
end
