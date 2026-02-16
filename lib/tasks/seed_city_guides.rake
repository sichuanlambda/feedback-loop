namespace :places do
  desc "Seed a city guide with notable buildings and AI content (e.g., rake places:seed_city['San Francisco'])"
  task :seed_city, [:city_name] => :environment do |_task, args|
    city_name = args[:city_name]

    if city_name.blank?
      puts "Usage: rake places:seed_city['San Francisco']"
      puts "Available cities: #{CityGuideSeeder::CITY_DATA.keys.join(', ')}"
      return
    end

    CityGuideSeeder.seed_city(city_name)
  end

  desc "Seed all available city guides"
  task seed_all_cities: :environment do
    CityGuideSeeder.seed_all
  end
end

  desc "Delete building analyses by ID range (e.g., rake places:delete_buildings[858,867])"
  task :delete_buildings, [:start_id, :end_id] => :environment do |_task, args|
    start_id = args[:start_id].to_i
    end_id = args[:end_id].to_i

    if start_id <= 0 || end_id <= 0 || end_id < start_id
      puts "Usage: rake places:delete_buildings[858,867]"
      return
    end

    buildings = BuildingAnalysis.where(id: start_id..end_id)
    count = buildings.count
    puts "Deleting #{count} building analyses (IDs #{start_id}-#{end_id})..."
    buildings.destroy_all
    puts "Done. Deleted #{count} records."
  end
