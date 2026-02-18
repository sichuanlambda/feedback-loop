namespace :images do
  desc "Download external image URLs to S3 for buildings that reference non-S3 images"
  task migrate_external: :environment do
    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    bucket = s3.bucket('architecture-explorer')

    # Find buildings with non-S3 image URLs
    buildings = BuildingAnalysis.where.not(image_url: [nil, ''])
                                .where.not("image_url LIKE ?", "%amazonaws.com%")

    puts "Found #{buildings.count} buildings with external image URLs"

    buildings.find_each do |building|
      print "  ##{building.id} #{building.name || 'unnamed'}: "

      begin
        # Download image
        image_data = URI.open(building.image_url,
          "User-Agent" => "ArchitectureHelper/1.0 (https://architecturehelper.com; atlas@architecturehelper.com)",
          read_timeout: 15
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
        sleep 1 # Rate limit
      rescue => e
        puts "❌ #{e.message}"
      end
    end

    puts "Done!"
  end
end
