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
end
