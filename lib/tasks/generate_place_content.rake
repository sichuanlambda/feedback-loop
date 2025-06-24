namespace :places do
  desc "Generate content and images for places that need them"
  task generate_content: :environment do
    places_needing_content = Place.needs_content.limit(10)
    
    if places_needing_content.empty?
      puts "No places need content generation."
      return
    end
    
    puts "Generating content for #{places_needing_content.count} places..."
    
    places_needing_content.each do |place|
      puts "Processing #{place.name}..."
      GeneratePlaceContentJob.perform_now(place.id)
      sleep(2) # Rate limiting
    end
    
    puts "Content generation complete!"
  end

  desc "Generate content for a specific place"
  task :generate_for_place, [:place_id] => :environment do |task, args|
    place_id = args[:place_id]
    
    if place_id.blank?
      puts "Please provide a place ID: rake places:generate_for_place[123]"
      return
    end
    
    place = Place.find(place_id)
    puts "Generating content for #{place.name}..."
    GeneratePlaceContentJob.perform_now(place.id)
    puts "Content generation complete!"
  end

  desc "Show places that need content generation"
  task list_needing_content: :environment do
    places = Place.needs_content
    
    if places.empty?
      puts "All places have content!"
    else
      puts "Places needing content generation:"
      places.each do |place|
        puts "  #{place.id}: #{place.name}"
      end
    end
  end
end 