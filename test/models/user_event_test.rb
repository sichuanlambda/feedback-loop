require "test_helper"

class UserEventTest < ActiveSupport::TestCase
  HUMAN = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36".freeze
  BOT = "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)".freeze

  test "flags crawlers on save and keeps people and server-side rows" do
    person = UserEvent.create!(event_type: "page_view", session_id: "a", user_agent: HUMAN)
    crawler = UserEvent.create!(event_type: "page_view", session_id: "b", user_agent: BOT)
    server = UserEvent.create!(event_type: "credit_reminder_sent", user_agent: nil)

    refute person.bot
    assert crawler.bot
    refute server.bot
    assert_equal [person.id, server.id].sort, UserEvent.human.where(id: [person.id, crawler.id, server.id]).pluck(:id).sort
  end

  test "track goes through the same classification" do
    request = Struct.new(:remote_ip, :user_agent).new("203.0.113.9", BOT)
    assert UserEvent.track(event_type: "guest_analysis_started", request: request).bot
  end
end
