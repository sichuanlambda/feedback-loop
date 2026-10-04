require "test_helper"

class VisitorTrackingTest < ActionDispatch::IntegrationTest
  CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36".freeze

  test "a first visit is recorded with a session id that the beacon and later pages share" do
    get "/blog", headers: { "User-Agent" => CHROME, "Referer" => "https://www.google.com/" }
    assert_response :success

    landing = UserEvent.where(event_type: "page_view").last
    assert landing.session_id.present?, "the landing page view must not be stored without a session"
    assert_equal "https://www.google.com/", landing.metadata["referrer"]

    post "/api/events", params: { event_type: "js_pageview", metadata: { path: "/blog", referrer: "https://www.google.com/" } },
                        headers: { "User-Agent" => CHROME }, as: :json
    get "/pricing", headers: { "User-Agent" => CHROME }

    assert_equal [landing.session_id], UserEvent.where(event_type: %w[js_pageview page_view]).distinct.pluck(:session_id)
  end

  test "the beacon sends an outside referrer without its query string" do
    get "/blog", headers: { "User-Agent" => CHROME }
    assert_includes response.body, "data.referrer = (ref.origin + ref.pathname)"
    assert_includes response.body, "keepalive: true"
  end
end
