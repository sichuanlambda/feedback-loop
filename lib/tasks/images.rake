require 'aws-sdk-s3'
require 'open-uri'

namespace :images do
  desc "Download external image URLs to S3 for buildings that reference non-S3 images"
  task migrate_external: :environment do
    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')

    # Find buildings with non-S3 image URLs (skip street view proxy URLs)
    buildings = BuildingAnalysis.where.not(image_url: [nil, ''])
                                .where.not("image_url LIKE ?", "%amazonaws.com%")
                                .where.not("image_url LIKE ?", "%/proxy/%")

    puts "Found #{buildings.count} buildings with external image URLs"

    buildings.find_each do |building|
      print "  ##{building.id} #{building.name || 'unnamed'}: "

      begin
        # Download image with proper User-Agent
        image_data = URI.open(building.image_url,
          "User-Agent" => "ArchitectureHelper/1.0 (https://architecturehelper.com; atlas@architecturehelper.com)",
          read_timeout: 30
        )

        ext = File.extname(URI.parse(building.image_url).path).split('?').first
        ext = '.jpg' if ext.blank?
        file_name = "building_#{building.id}_#{Time.now.to_i}#{ext}"
        object_key = "uploads/#{file_name}"

        obj = bucket.object(object_key)
        if obj.upload_file(image_data.path)
          building.update!(image_url: obj.public_url)
          puts "✅ → #{obj.public_url}"
        else
          puts "❌ S3 upload failed"
        end

        image_data.close if image_data.respond_to?(:close)
        sleep 5 # Respect Wikimedia rate limits
      rescue => e
        puts "❌ #{e.message.split("\n").first}"
        sleep 3
      end
    end

    puts "Done!"
  end

  desc "Search Wikimedia Commons and download images to S3 for buildings with broken URLs"
  task fix_broken_images: :environment do
    require 'net/http'
    require 'json'

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')

    # Find buildings with non-S3 image URLs
    buildings = BuildingAnalysis.where(visible_in_library: true)
                                .where.not(image_url: [nil, ''])
                                .where.not("image_url LIKE ?", "%amazonaws.com%")

    puts "Found #{buildings.count} buildings with non-S3 images"

    buildings.find_each do |building|
      print "  ##{building.id} #{building.name || 'unnamed'}: "

      begin
        # Search Wikimedia Commons for a good image
        search_query = "#{building.name} #{building.address&.split(',')&.last(2)&.join(' ')}".strip
        api_url = "https://commons.wikimedia.org/w/api.php?" + URI.encode_www_form(
          action: "query",
          generator: "search",
          gsrnamespace: 6,
          gsrsearch: search_query,
          gsrlimit: 1,
          prop: "imageinfo",
          iiprop: "url",
          iiurlwidth: 1200,
          format: "json"
        )

        uri = URI(api_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "ArchitectureHelper/1.0 (https://architecturehelper.com; atlas@architecturehelper.com)"
        response = http.request(req)
        data = JSON.parse(response.body)

        pages = data.dig("query", "pages") || {}
        thumb_url = nil
        pages.each do |_id, page_data|
          info = page_data.dig("imageinfo")&.first || {}
          thumb_url = info["thumburl"] || info["url"]
        end

        unless thumb_url
          puts "❌ No image found on Commons"
          sleep 2
          next
        end

        # Download the image
        image_data = URI.open(thumb_url,
          "User-Agent" => "ArchitectureHelper/1.0 (https://architecturehelper.com; atlas@architecturehelper.com)",
          read_timeout: 30
        )

        ext = File.extname(URI.parse(thumb_url).path).split('?').first
        ext = '.jpg' if ext.blank?
        file_name = "building_#{building.id}_#{Time.now.to_i}#{ext}"
        object_key = "uploads/#{file_name}"

        obj = bucket.object(object_key)
        if obj.upload_file(image_data.path)
          building.update!(image_url: obj.public_url)
          puts "✅ → #{obj.public_url}"
        else
          puts "❌ S3 upload failed"
        end

        image_data.close if image_data.respond_to?(:close)
        sleep 5 # Respect rate limits
      rescue => e
        puts "❌ #{e.message.split("\n").first}"
        sleep 5
      end
    end

    puts "Done!"
  end

  desc "Re-run GPT analysis for buildings missing analysis content"
  task reanalyze_missing: :environment do
    buildings = BuildingAnalysis.where(visible_in_library: true)
                                .where(html_content: [nil, ''])
                                .where.not(image_url: [nil, ''])

    puts "Found #{buildings.count} buildings missing analysis"

    buildings.find_each do |building|
      print "  ##{building.id} #{building.name || 'unnamed'}: "
      begin
        ProcessBuildingAnalysisJob.perform_later(building.id, building.image_url, building.address)
        puts "✅ enqueued"
      rescue => e
        puts "❌ #{e.message}"
      end
      sleep 2 # Space out to avoid Sidekiq overload
    end

    puts "Done! Jobs will process in background via Sidekiq."
  end

  desc "Generate thumbnails (400w) for all S3 building images"
  task generate_thumbnails: :environment do
    require 'mini_magick'
    require 'open-uri'
    require 'tempfile'

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')
    width = 400

    buildings = BuildingAnalysis.where(visible_in_library: true)
                                .where("image_url LIKE '%architecture-explorer.s3%'")
                                .where("image_url IS NOT NULL AND image_url != ''")

    puts "Found #{buildings.count} buildings with S3 images"
    generated = 0
    skipped = 0
    failed = 0

    buildings.find_each do |building|
      begin
        uri = URI.parse(building.image_url)
        path = uri.path.sub(/^\//, '') # e.g. uploads/building_123_456.jpg
        ext = File.extname(path)
        base = File.basename(path, ext)
        thumb_key = "uploads/thumbs/#{base}_#{width}w#{ext}"

        # Skip if thumbnail already exists
        if bucket.object(thumb_key).exists?
          skipped += 1
          next
        end

        # Download original
        temp = Tempfile.new(['thumb', ext])
        temp.binmode
        URI.open(building.image_url) { |f| temp.write(f.read) }
        temp.rewind

        # Resize with MiniMagick
        image = MiniMagick::Image.new(temp.path)
        image.resize "#{width}x#{width}>"  # Shrink to fit, maintain aspect ratio
        image.quality "85"

        # Upload thumbnail
        obj = bucket.object(thumb_key)
        obj.upload_file(temp.path, content_type: "image/jpeg", acl: "public-read")

        generated += 1
        puts "##{building.id} #{building.name}: ✅ #{thumb_key}"

        temp.close
        temp.unlink
        sleep 1 # Rate limit
      rescue => e
        failed += 1
        puts "##{building.id} #{building.name}: ❌ #{e.message}"
      end
    end

    puts "\nDone! Generated: #{generated}, Skipped: #{skipped}, Failed: #{failed}"
  end

  desc "Fix a single building's image from a URL: rake images:fix_one[BUILDING_ID,IMAGE_URL]"
  task :fix_one, [:building_id, :image_url] => :environment do |t, args|
    require 'open-uri'

    bid = args[:building_id].to_i
    url = args[:image_url]

    abort "Usage: rake images:fix_one[BUILDING_ID,IMAGE_URL]" if bid == 0 || url.blank?

    building = BuildingAnalysis.find(bid)
    puts "Fixing ##{bid} #{building.name}..."

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')

    # Download image
    ext = File.extname(URI.parse(url).path).presence || '.jpg'
    key = "uploads/building_#{bid}_#{Time.now.to_i}#{ext}"

    temp = Tempfile.new(['fix', ext])
    temp.binmode
    URI.open(url, "User-Agent" => "ArchitectureHelper/1.0") { |f| temp.write(f.read) }
    temp.rewind

    obj = bucket.object(key)
    obj.upload_file(temp.path, content_type: "image/jpeg", acl: "public-read")

    building.update!(image_url: obj.public_url)
    puts "✅ Updated to #{obj.public_url}"

    temp.close
    temp.unlink
  end

  desc "Fix multiple buildings from a JSON map: rake images:fix_batch"
  task fix_batch: :environment do
    require 'open-uri'

    # Hardcoded fixes for buildings that failed Commons search
    fixes = {
      995  => "https://upload.wikimedia.org/wikipedia/commons/thumb/d/de/View_of_Center_City_%28Comcast_Technology_Center%29_%28Cropped_9_to_16%29.jpg/1280px-View_of_Center_City_%28Comcast_Technology_Center%29_%28Cropped_9_to_16%29.jpg",
      1001 => "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Cathedral_Basilica_of_Saints_Peter_and_Paul_in_Philadelphia_20240528.jpg/1280px-Cathedral_Basilica_of_Saints_Peter_and_Paul_in_Philadelphia_20240528.jpg",
      1002 => "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Philadelphia_-_Elfreths_Alley_-_20241031164637.jpg/1280px-Philadelphia_-_Elfreths_Alley_-_20241031164637.jpg",
      1012 => "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Trinity_Church%2C_Boston%2C_Massachusetts_-_front_oblique_view.JPG/1280px-Trinity_Church%2C_Boston%2C_Massachusetts_-_front_oblique_view.JPG",
      1020 => "https://upload.wikimedia.org/wikipedia/commons/5/5e/John_Hancock_Tower%2C_200_Clarendon.jpg",
      1023 => "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/20180527_-_05_-_Boston%2C_MA_%28Isabella_Stewart_Gardner_Museum%29.jpg/1280px-20180527_-_05_-_Boston%2C_MA_%28Isabella_Stewart_Gardner_Museum%29.jpg",
      1024 => "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Stata_Center_%2805689p%292.jpg/1280px-Stata_Center_%2805689p%292.jpg",
    }

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')

    fixes.each do |bid, url|
      begin
        building = BuildingAnalysis.find(bid)
        ext = File.extname(URI.parse(url).path).presence || '.jpg'
        key = "uploads/building_#{bid}_#{Time.now.to_i}#{ext}"

        temp = Tempfile.new(['fix', ext])
        temp.binmode
        URI.open(url, "User-Agent" => "ArchitectureHelper/1.0") { |f| temp.write(f.read) }
        temp.rewind

        obj = bucket.object(key)
        obj.upload_file(temp.path, content_type: "image/jpeg", acl: "public-read")
        building.update!(image_url: obj.public_url)

        puts "##{bid} #{building.name}: ✅ #{obj.public_url}"
        temp.close; temp.unlink
        sleep 5
      rescue => e
        puts "##{bid}: ❌ #{e.message}"
      end
    end
  end
end
