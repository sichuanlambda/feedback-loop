namespace :sitemap do
  desc "Generate sitemap"
  task generate: :environment do
    puts "Generating sitemap..."
    
    # Load the sitemap configuration
    load Rails.root.join('config', 'sitemap.rb')
    
    puts "Sitemap generated successfully!"
    puts "Sitemap location: #{Rails.root.join('public', 'sitemap.xml')}"
  end
  
  desc "Generate sitemap and ping search engines"
  task ping: :environment do
    puts "Generating sitemap and pinging search engines..."
    
    # Generate sitemap
    Rake::Task['sitemap:generate'].invoke
    
    # Ping search engines
    SitemapGenerator::Sitemap.ping_search_engines
    
    puts "Sitemap generated and search engines pinged!"
  end
  
  desc "Update sitemap for a specific place"
  task :update_place, [:place_id] => :environment do |t, args|
    place_id = args[:place_id]
    
    if place_id.blank?
      puts "Please provide a place ID: rake sitemap:update_place[123]"
      exit 1
    end
    
    place = Place.find(place_id)
    
    if place.published?
      puts "Updating sitemap for place: #{place.name}"
      Rake::Task['sitemap:generate'].invoke
      puts "Sitemap updated!"
    else
      puts "Place #{place.name} is not published. Skipping sitemap update."
    end
  end
end 