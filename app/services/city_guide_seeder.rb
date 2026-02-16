class CityGuideSeeder
  CITY_DATA = {
    "San Francisco" => {
      latitude: 37.7749,
      longitude: -122.4194,
      zoom_level: 13,
      description: "Explore San Francisco's extraordinary architectural diversity — from Victorian painted ladies and Beaux-Arts civic buildings to cutting-edge contemporary towers reshaping the skyline.",
      meta_title: "San Francisco Architecture Guide — Victorian, Beaux-Arts & Modern Styles",
      meta_description: "Discover San Francisco's architectural heritage. Explore Victorian painted ladies, Beaux-Arts landmarks, Art Deco gems, and cutting-edge contemporary buildings across the city's iconic neighborhoods.",
      notable_buildings: [
        {
          address: "1000 Thomas L Berkley Way, San Francisco, CA",
          latitude: 37.7860,
          longitude: -122.4095,
          description: "Transamerica Pyramid — San Francisco's most recognizable skyscraper, designed by William Pereira in 1972. A bold Futurist statement in the Financial District.",
          styles: ["Futurism", "Modernism", "International Style"]
        },
        {
          address: "301 Van Ness Ave, San Francisco, CA",
          latitude: 37.7764,
          longitude: -122.4200,
          description: "San Francisco City Hall — Arthur Brown Jr.'s 1915 Beaux-Arts masterpiece, with a dome taller than the U.S. Capitol.",
          styles: ["Beaux-Arts", "Neoclassical", "Renaissance Revival"]
        },
        {
          address: "710-720 Steiner St, San Francisco, CA",
          latitude: 37.7759,
          longitude: -122.4328,
          description: "Painted Ladies at Alamo Square — iconic row of Victorian and Edwardian houses, one of the most photographed locations in San Francisco.",
          styles: ["Victorian", "Queen Anne", "Edwardian"]
        },
        {
          address: "750 Kearny St, San Francisco, CA",
          latitude: 37.7950,
          longitude: -122.4050,
          description: "Transamerica Redwood Park area — Financial District's mix of historic low-rises and modern towers.",
          styles: ["Art Deco", "Modernism", "Contemporary"]
        },
        {
          address: "201 3rd St, San Francisco, CA",
          latitude: 37.7857,
          longitude: -122.4011,
          description: "San Francisco Museum of Modern Art (SFMOMA) — Mario Botta's 1995 design expanded by Snøhetta in 2016. A landmark of contemporary museum architecture.",
          styles: ["Postmodernism", "Contemporary", "Deconstructivism"]
        },
        {
          address: "1 Sausalito - San Francisco Ferry Building, San Francisco, CA",
          latitude: 37.7956,
          longitude: -122.3935,
          description: "Ferry Building — 1898 Beaux-Arts terminal with its iconic clock tower, beautifully restored as a food marketplace.",
          styles: ["Beaux-Arts", "Mission Revival", "Renaissance Revival"]
        },
        {
          address: "1 Dr Carlton B Goodlett Pl, San Francisco, CA",
          latitude: 37.7793,
          longitude: -122.4193,
          description: "War Memorial Opera House — another Arthur Brown Jr. masterpiece (1932), Beaux-Arts grandeur at the Civic Center.",
          styles: ["Beaux-Arts", "Neoclassical"]
        },
        {
          address: "135 Main St, San Francisco, CA",
          latitude: 37.7914,
          longitude: -122.3930,
          description: "Salesforce Tower — César Pelli's 2018 supertall tower, now the city's tallest building at 1,070 feet with a public art installation crown.",
          styles: ["Contemporary", "International Style", "Modernism"]
        }
      ]
    },
    "Chicago" => {
      latitude: 41.8781,
      longitude: -87.6298,
      zoom_level: 13,
      description: "Discover the birthplace of the skyscraper. Chicago's architecture spans from pioneering Chicago School buildings to Prairie Style homes, Art Deco towers, and Mies van der Rohe's modernist masterworks.",
      meta_title: "Chicago Architecture Guide — Birthplace of the Skyscraper",
      meta_description: "Explore Chicago's legendary architectural heritage. From the Chicago School and Prairie Style to Art Deco and modernist masterworks by Mies van der Rohe, Frank Lloyd Wright, and more.",
      notable_buildings: [
        {
          address: "233 S Wacker Dr, Chicago, IL",
          latitude: 41.8789,
          longitude: -87.6359,
          description: "Willis Tower (Sears Tower) — Fazlur Rahman Khan's 1973 structural marvel, once the world's tallest building. Bundled tube design that revolutionized skyscraper engineering.",
          styles: ["Modernism", "International Style", "Structural Expressionism"]
        },
        {
          address: "330 N Wabash Ave, Chicago, IL",
          latitude: 41.8887,
          longitude: -87.6263,
          description: "AMA Plaza (IBM Building) — Mies van der Rohe's 1973 dark aluminum and glass tower, his last American skyscraper. Pure International Style.",
          styles: ["International Style", "Modernism", "Minimalism"]
        },
        {
          address: "860-880 N Lake Shore Dr, Chicago, IL",
          latitude: 41.8993,
          longitude: -87.6186,
          description: "860-880 Lake Shore Drive Apartments — Mies van der Rohe's revolutionary 1951 glass-and-steel towers that defined modernist residential architecture worldwide.",
          styles: ["International Style", "Modernism", "Minimalism"]
        },
        {
          address: "111 S Michigan Ave, Chicago, IL",
          latitude: 41.8796,
          longitude: -87.6246,
          description: "Art Institute of Chicago — 1893 Beaux-Arts original by Shepley, Rutan and Coolidge, with Renzo Piano's stunning 2009 Modern Wing addition.",
          styles: ["Beaux-Arts", "Contemporary", "Modernism"]
        },
        {
          address: "951 Chicago Ave, Oak Park, IL",
          latitude: 41.8917,
          longitude: -87.7996,
          description: "Frank Lloyd Wright Home and Studio — Wright's personal laboratory in Oak Park where Prairie Style was born (1889-1909).",
          styles: ["Prairie Style", "Arts and Crafts", "Organic Architecture"]
        },
        {
          address: "55 E Randolph St, Chicago, IL",
          latitude: 41.8847,
          longitude: -87.6252,
          description: "Cloud Gate ('The Bean') at Millennium Park — Anish Kapoor's iconic 2006 sculpture in a park defined by Frank Gehry's Pritzker Pavilion.",
          styles: ["Contemporary", "Deconstructivism", "Postmodernism"]
        },
        {
          address: "875 N Michigan Ave, Chicago, IL",
          latitude: 41.8988,
          longitude: -87.6229,
          description: "John Hancock Center — Fazlur Khan and Bruce Graham's 1969 X-braced tower. Structural Expressionism that turned engineering into art.",
          styles: ["Structural Expressionism", "Modernism", "International Style"]
        },
        {
          address: "209 S LaSalle St, Chicago, IL",
          latitude: 41.8793,
          longitude: -87.6321,
          description: "Rookery Building — Burnham & Root's 1888 masterpiece with a light court remodeled by Frank Lloyd Wright in 1905. Where Chicago School meets Prairie Style.",
          styles: ["Chicago School", "Romanesque Revival", "Prairie Style"]
        },
        {
          address: "401 N Wabash Ave, Chicago, IL",
          latitude: 41.8899,
          longitude: -87.6268,
          description: "Trump International Hotel & Tower — Adrian Smith's 2009 glass tower, one of the tallest buildings in the Western Hemisphere at the Chicago River bend.",
          styles: ["Contemporary", "Postmodernism", "International Style"]
        },
        {
          address: "35 E Wacker Dr, Chicago, IL",
          latitude: 41.8869,
          longitude: -87.6260,
          description: "Jewelers Building (Pure Chicago) — 1927 Art Deco tower by Thielbar and Fugard, once the tallest building in the world outside NYC.",
          styles: ["Art Deco", "Neoclassical", "Chicago School"]
        }
      ]
    }
  }.freeze

  def self.seed_city(city_name)
    data = CITY_DATA[city_name]
    raise "Unknown city: #{city_name}. Available: #{CITY_DATA.keys.join(', ')}" unless data

    puts "Seeding city guide for #{city_name}..."

    # Create or find the place
    place = Place.find_or_initialize_by(name: city_name)
    place.assign_attributes(
      latitude: data[:latitude],
      longitude: data[:longitude],
      zoom_level: data[:zoom_level],
      description: data[:description],
      meta_title: data[:meta_title],
      meta_description: data[:meta_description],
      published: true,
      featured: true
    )

    if place.save
      puts "  ✓ Place '#{city_name}' #{place.previously_new_record? ? 'created' : 'updated'} (slug: #{place.slug})"
    else
      puts "  ✗ Failed to save place: #{place.errors.full_messages.join(', ')}"
      return nil
    end

    # Seed notable buildings — assign to first admin or first user
    system_user = User.find_by(admin: true) || User.first
    seeded_count = 0
    data[:notable_buildings].each do |building_data|
      building = BuildingAnalysis.find_or_initialize_by(
        address: building_data[:address]
      )

      # Only set defaults on new records
      if building.new_record?
        building.assign_attributes(
          latitude: building_data[:latitude],
          longitude: building_data[:longitude],
          city: city_name,
          visible_in_library: true,
          h3_contents: building_data[:styles].to_json,
          html_content: build_building_html(building_data),
          user: system_user
        )

        save_result = system_user ? building.save : building.save(validate: false)
        if save_result
          seeded_count += 1
          puts "  ✓ Building: #{building_data[:address]}"
        else
          puts "  ✗ Failed: #{building_data[:address]} — #{building.errors.full_messages.join(', ')}"
        end
      else
        puts "  → Exists: #{building_data[:address]}"
      end
    end

    puts "  Seeded #{seeded_count} new buildings for #{city_name}"

    # Generate AI content for the place
    if place.content.blank?
      puts "  Generating AI content for #{city_name}..."
      generator = PlaceContentGenerator.new(place)
      generator.generate_content_and_images
      place.reload
      if place.content.present?
        puts "  ✓ AI content generated (#{place.content.length} chars)"
      else
        puts "  → Using fallback content (AI generation unavailable or failed)"
      end
    else
      puts "  → Content already exists, skipping generation"
    end

    place
  end

  def self.seed_all
    CITY_DATA.keys.each { |city| seed_city(city) }
  end

  private

  def self.build_building_html(building_data)
    styles_html = building_data[:styles].map do |style|
      "<h3>#{style}</h3>"
    end.join("\n")

    <<~HTML
      <div class="building-analysis">
        <p>#{building_data[:description]}</p>
        #{styles_html}
      </div>
    HTML
  end
end
