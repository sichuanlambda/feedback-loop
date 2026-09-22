# Coarse per-IP throttling. Scrapers (many posing as desktop Chrome) were making
# hundreds of thousands of requests a month; real visitors never come close to
# these limits. Counters live in process memory, so with several Puma workers
# the effective ceiling is a multiple of the numbers below — fine for this job.
class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Search engines we want crawling freely. UA strings can be spoofed, but the
  # worst case is that a spoofer gets the unthrottled experience it has today.
  SEARCH_ENGINE_UA = /googlebot|bingbot|duckduckbot|applebot|yandexbot/i

  safelist('search engines') { |req| SEARCH_ENGINE_UA.match?(req.user_agent.to_s) }
  safelist('webhooks and assets') do |req|
    req.path == '/stripe_events' || req.path.start_with?('/assets/', '/rails/active_storage/')
  end

  # Pages: 90 per minute per IP is ~1.5 page loads a second, sustained.
  throttle('pages/ip', limit: 90, period: 1.minute) { |req| req.ip if req.get? }

  # Expensive AI endpoints: a person submits a handful of these, not dozens.
  throttle('ai submits/ip', limit: 12, period: 1.hour) do |req|
    req.ip if req.post? && ['/architecture_explorer', '/restyle', '/designs/submit', '/generate_image'].include?(req.path)
  end

  # Credential stuffing guard on sign-in
  throttle('logins/ip', limit: 10, period: 5.minutes) { |req| req.ip if req.post? && req.path == '/users/sign_in' }

  self.throttled_responder = lambda do |request|
    retry_after = (request.env['rack.attack.match_data'] || {})[:period]
    [429, { 'Content-Type' => 'text/plain', 'Retry-After' => retry_after.to_s }, ["Too many requests. Please slow down and try again shortly.\n"]]
  end
end

# Off in test so request specs are never throttled
Rack::Attack.enabled = !Rails.env.test?
