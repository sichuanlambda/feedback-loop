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
