require "test_helper"

class Admin::BuildingAnalysesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_building_analyses_index_url
    assert_response :success
  end

  test "should get show" do
    get admin_building_analyses_show_url
    assert_response :success
  end

  test "should get edit" do
    get admin_building_analyses_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_building_analyses_update_url
    assert_response :success
  end

  test "should get destroy" do
    get admin_building_analyses_destroy_url
    assert_response :success
  end
end
