# User-agent sniffing for crawlers and scripted clients. Roughly 60% of tracked
# events were bots, which drowned out the admin analytics, and cookie-keeping AI
# crawlers were tripping the three-free-views gate on building pages.
module BotDetector
  BOT_UA = /
    bot\b|bot\/|crawl|spider|slurp|bingpreview|facebookexternalhit|meta-external|
    headless|phantomjs|python|curl|wget|scrapy|httpclient|go-http|java\/|okhttp|
    axios|node-fetch|ruby|libwww|ahrefs|semrush|mj12|petal|bytespider|gptbot|
    chatgpt|oai-search|claude|anthropic|perplexity|ccbot|amazonbot|applebot|
    yandex|baidu|duckduck|dataforseo|lighthouse|pingdom|uptime|monitor|feedfetcher
  /xi

  def self.bot?(user_agent)
    user_agent.blank? || BOT_UA.match?(user_agent)
  end
end
