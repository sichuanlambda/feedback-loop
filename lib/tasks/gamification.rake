namespace :gamification do
  desc "Backfill style collections and levels for all users based on existing building analyses"
  task backfill: :environment do
    puts "Starting gamification backfill..."
    
    users_with_buildings = User.joins(:building_analyses)
                              .where.not(email: 'atlas@architecturehelper.com')
                              .distinct
    
    total = users_with_buildings.count
    puts "Found #{total} users with building analyses"
    
    users_with_buildings.find_each.with_index do |user, idx|
      analyses = user.building_analyses.where.not(h3_contents: [nil, "", "[]"])
      style_count = 0
      
      analyses.each do |analysis|
        begin
          StyleCollectionService.update_collections_for_building(user, analysis)
          style_count += 1
        rescue => e
          puts "  Error processing analysis #{analysis.id} for user #{user.id}: #{e.message}"
        end
      end
      
      # Update level
      begin
        LevelCalculationService.update_user_level(user)
      rescue => e
        puts "  Error updating level for user #{user.id}: #{e.message}"
      end
      
      level = UserLevel.find_by(user_id: user.id)
      collections = user.user_style_collections.count
      puts "[#{idx+1}/#{total}] User #{user.id} (#{user.handle}): #{analyses.count} analyses → #{collections} style collections, Level #{level&.level}, #{level&.total_points} pts"
    end
    
    puts "\nBackfill complete!"
    puts "Total style collections: #{UserStyleCollection.count}"
    puts "Total user levels: #{UserLevel.count}"
  end
end
