# Builds the /admin/growth report on the worker and caches it, because the
# aggregation takes longer than the 30s Heroku allows a web request. The page
# reads the cached copy and re-queues a build once it is an hour old
# (stale-while-revalidate), so it always loads instantly.
class GrowthReportJob < ApplicationJob
  queue_as :default

  TTL = 6.hours
  FRESH_FOR = 1.hour

  def self.cache_key(days, exclude_user_ids)
    ['growth-report', days, exclude_user_ids.sort.join('-')].join(':')
  end

  def self.lock_key(days, exclude_user_ids)
    "#{cache_key(days, exclude_user_ids)}:building"
  end

  # Returns the cached report (possibly stale) or nil, and queues a rebuild
  # when there is none or it has gone stale. The lock stops every page load
  # during a build from queueing another one.
  def self.fetch(days:, exclude_user_ids:)
    report = Rails.cache.read(cache_key(days, exclude_user_ids))
    stale = report.nil? || report[:built_at] < FRESH_FOR.ago
    if stale && Rails.cache.write(lock_key(days, exclude_user_ids), Time.current, expires_in: 10.minutes, unless_exist: true)
      perform_later(days, exclude_user_ids)
    end
    report
  end

  def perform(days, exclude_user_ids)
    report = GrowthReport.new(days: days, exclude_user_ids: exclude_user_ids).build.merge(built_at: Time.current)
    Rails.cache.write(self.class.cache_key(days, exclude_user_ids), report, expires_in: TTL)
  ensure
    Rails.cache.delete(self.class.lock_key(days, exclude_user_ids))
  end
end
