require 'net/http'
require 'json'
require 'zlib'

namespace :seo do
  desc "Submit URLs to IndexNow (Bing, Yandex, Naver, Seznam). Default: blog posts from the last DAYS=7. URLS=/a,/b for specific paths; ALL=1 for every sitemap URL."
  task indexnow: :environment do
    key = ENV['INDEXNOW_KEY'].to_s
    abort 'INDEXNOW_KEY is not set (heroku config:set INDEXNOW_KEY=...)' if key.blank?

    host = URI(ENV.fetch('CANONICAL_HOST', 'https://architecturehelper.com')).host

    paths =
      if ENV['URLS'].present?
        ENV['URLS'].split(',').map(&:strip).reject(&:blank?)
      elsif ENV['ALL'] == '1'
        xml = Zlib::GzipReader.open(Rails.root.join('public', 'sitemap1.xml.gz'), &:read)
        xml.scan(%r{<loc>https?://[^/<]+(/[^<]*)?</loc>}).flatten.map { |p| p.presence || '/' }
      else
        days = (ENV['DAYS'] || 7).to_i
        BlogPost.published.where('published_at >= ?', days.days.ago).pluck(:slug).map { |s| "/blog/#{s}" }
      end

    abort 'Nothing to submit' if paths.empty?
    urls = paths.map { |p| "https://#{host}#{p}" }.uniq

    # IndexNow accepts up to 10,000 URLs per request. 200 = accepted, 202 =
    # accepted but the key file has not been verified yet.
    urls.each_slice(10_000) do |batch|
      body = { host: host, key: key, keyLocation: "https://#{host}/indexnow-key.txt", urlList: batch }
      res = Net::HTTP.post(URI('https://api.indexnow.org/indexnow'), body.to_json,
                           'Content-Type' => 'application/json; charset=utf-8')
      puts "IndexNow #{res.code} #{res.message} — #{batch.size} URL(s)"
      puts res.body if res.code.to_i >= 400 && res.body.present?
    end

    puts urls.first(20)
    puts "… #{urls.size} total" if urls.size > 20
  end
end
