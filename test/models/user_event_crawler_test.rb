require "test_helper"

class UserEventCrawlerTest < ActiveSupport::TestCase
  UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36".freeze

  def view(session, path, at)
    UserEvent.create!(event_type: "page_view", session_id: session, user_agent: UA, metadata: { path: path }, created_at: at)
  end

  test "sessions that fetch three pages in one second without running JS are flagged" do
    t = Time.zone.parse("2026-09-27 10:46:12")
    view("crawler", "/a", t); view("crawler", "/b", t); view("crawler", "/c", t)
    view("crawler", "/d", t + 20.minutes)
    view("person", "/a", t); view("person", "/b", t + 30.seconds); view("person", "/c", t + 90.seconds)
    # A real browser whose service worker precached pages in the same second, but which ran the beacon
    view("browser", "/", t); view("browser", "/x", t); view("browser", "/y", t)
    UserEvent.create!(event_type: "js_pageview", session_id: "browser", user_agent: UA, metadata: { path: "/" }, created_at: t + 5.seconds)

    flagged = UserEvent.flag_parallel_crawlers!(since: t - 1.hour)

    assert_equal 4, flagged
    assert UserEvent.where(session_id: "crawler").all?(&:bot)
    assert UserEvent.where(session_id: %w[person browser]).none?(&:bot)
    assert_equal 0, UserEvent.flag_parallel_crawlers!(since: t - 1.hour), "re-running flags nothing new"
  end
end
