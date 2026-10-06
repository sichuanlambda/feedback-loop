# Dedicated city photos for the city guides.
#
# config/place_images.yml maps a Place name to one hand-picked Wikimedia Commons
# photo. This task copies each photo to our own S3 bucket in two sizes (hero and
# card) and points the Place at them, so guides stop borrowing a random building.
namespace :places do
  desc 'Set each city guide photo from config/place_images.yml. DRY=1 to preview; ONLY="Denver,Boston" to target; FORCE=1 to redo cities already set.'
  task set_hero_images: :environment do
    only = ENV['ONLY'].to_s.split(',').map(&:strip).reject(&:blank?)
    dry = ENV['DRY'].present?
    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')
    done = skipped = failed = 0

    PlaceImage.all.each do |name, image|
      next if only.any? && !only.include?(name)

      place = Place.find_by(name: name)
      if place.nil?
        puts "SKIP #{name}: no such place"
        skipped += 1
        next
      end
      if place.image_source == PlaceImage::SOURCE && place.hero_image_url.to_s.include?(image.s3_key(:hero)) && ENV['FORCE'].blank?
        puts "SKIP #{name}: already set"
        skipped += 1
        next
      end
      if dry
        puts "DRY  #{name} <- #{image.file} (#{image.credit})"
        next
      end

      urls = PlaceImage::SIZES.keys.index_with do |size|
        response = HTTParty.get(image.download_url(size), timeout: 60, follow_redirects: true,
                                headers: { 'User-Agent' => PlaceImage::USER_AGENT })
        raise "HTTP #{response.code} fetching #{size}" unless response.code == 200 && response.headers['content-type'].to_s.start_with?('image/')

        obj = bucket.object(image.s3_key(size))
        obj.put(body: response.body, content_type: 'image/jpeg', cache_control: 'public, max-age=31536000')
        sleep 1
        obj.public_url
      end

      place.update_columns(hero_image_url: urls[:hero], representative_image_url: urls[:card],
                           hero_image_alt: image.alt, image_source: PlaceImage::SOURCE)
      done += 1
      puts "OK   #{name} -> #{urls[:hero]}"
    rescue => e
      failed += 1
      puts "FAIL #{name}: #{e.class} #{e.message.truncate(160)}"
    end

    missing = Place.published.where.not(name: PlaceImage.all.keys).pluck(:name)
    puts "City photos: #{done} set, #{skipped} skipped, #{failed} failed"
    puts "Published places with no entry in config/place_images.yml: #{missing.join(', ')}" if missing.any?
  end
end
