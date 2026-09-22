require "test_helper"

class AdminGrowthDashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HUMAN = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1".freeze
  BOT = "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ClaudeBot/1.0; +claudebot@anthropic.com)".freeze

  def event(type, session, agent, metadata = {})
    UserEvent.create!(event_type: type, session_id: session, user_agent: agent, metadata: metadata, created_at: 1.day.ago)
  end

  setup do
    @admin = User.create!(email: "admin@example.com", password: "password123", terms_of_service: "1", admin: true)
    sign_in @admin
  end

  test "counts people, ignores crawlers, and attributes search traffic" do
    event("page_view", "s1", HUMAN, { path: "/blog/gothic", referrer: "https://www.google.com/" })
    event("page_view", "s1", HUMAN, { path: "/pricing", referrer: "https://architecturehelper.com/blog/gothic" })
    event("page_view", "s2", HUMAN, { path: "/", referrer: nil })
    event("building_new_form", "s2", HUMAN)
    event("guest_analysis_started", "s2", HUMAN, { building_id: 1 })
    # A crawler that keeps cookies and browses like a person must not count
    event("page_view", "b1", BOT, { path: "/blog/gothic", referrer: "https://www.bing.com/" })
    event("page_view", "b1", BOT, { path: "/pricing", referrer: "https://architecturehelper.com/" })
    event("building_new_form", "b1", BOT)

    get admin_growth_path

    assert_response :success
    assert_select "[data-kpi=sessions]", text: "2"
    assert_select "[data-kpi=engaged]", text: "1"
    assert_select "[data-kpi=search]", text: "1"
    assert_select "[data-kpi=tools]", text: "1"
    assert_select "[data-funnel=form_views]", text: "1"
    assert_select "[data-funnel=analyses_started]", text: "1"
    assert_select "tr[data-source='google.com'] td.num", text: "1"
    assert_select "tr[data-source='bing.com']", 0
    assert_select "tr[data-landing='/blog/gothic'] td.num", text: "1"
    assert_select "tr[data-device=mobile] [data-col=sessions]", text: "2"
    assert_select "tr[data-device=desktop] [data-col=sessions]", text: "0"
  end

  test "internal users can be excluded without losing signed-out traffic" do
    internal = User.create!(email: Admin::AnalyticsController::EXCLUDED_EMAILS.first, password: "password123", terms_of_service: "1")
    UserEvent.create!(event_type: "page_view", session_id: "me", user_agent: HUMAN, user: internal, metadata: { path: "/" }, created_at: 1.day.ago)
    event("page_view", "guest", HUMAN, { path: "/" })

    get admin_growth_path
    assert_select "[data-kpi=sessions]", text: "1"

    get admin_growth_path(exclude_internal: "0")
    assert_select "[data-kpi=sessions]", text: "2"
  end

  test "non-admins are turned away" do
    sign_out :user
    get admin_growth_path
    assert_redirected_to root_path
  end
end
