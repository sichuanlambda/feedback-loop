namespace :buildings do
  desc 'Geocode visible buildings that have an address but no coordinates. LIMIT=n to batch, DRY=1 to preview.'
  task geocode_missing: :environment do
    scope = BuildingAnalysis.where(visible_in_library: true)
                            .where(latitude: nil)
                            .where.not(address: [nil, '', 'N/A', 'AI'])
                            .order(:id)
    limit = ENV['LIMIT'].to_i
    scope = scope.limit(limit) if limit.positive?

    # Google location_types precise enough to drop a building pin.
    # APPROXIMATE (city-level) results would pin real buildings at city
    # centers, which misleads on a map, so those are skipped.
    precise = %w[ROOFTOP RANGE_INTERPOLATED GEOMETRIC_CENTER]

    done = vague = failed = 0
    scope.each do |building|
      results = Geocoder.search(building.address)
      result = results.first
      if result.nil?
        failed += 1
        puts "FAIL  #{building.id} no result for #{building.address.inspect}"
        next
      end

      location_type = result.data.dig('geometry', 'location_type')
      unless precise.include?(location_type)
        vague += 1
        puts "VAGUE #{building.id} #{location_type} for #{building.address.inspect}"
        next
      end

      if ENV['DRY'] == '1'
        puts "DRY   #{building.id} #{result.latitude},#{result.longitude} (#{location_type}) #{building.address.inspect}"
      else
        building.update_columns(latitude: result.latitude, longitude: result.longitude)
        puts "OK    #{building.id} #{result.latitude},#{result.longitude} (#{location_type})"
      end
      done += 1
      sleep 0.2
    rescue => e
      failed += 1
      puts "FAIL  #{building.id}: #{e.class} #{e.message.to_s[0, 120]}"
      sleep 1
    end

    puts "Geocode backfill: #{done} #{ENV['DRY'] == '1' ? 'geocodable' : 'updated'}, #{vague} too vague to pin, #{failed} failed"
  end
end
