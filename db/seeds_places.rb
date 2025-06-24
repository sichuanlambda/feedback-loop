# Seeds for Places
puts "Creating sample places..."

# Denver, Colorado
denver = Place.find_or_create_by(name: "Denver, Colorado") do |place|
  place.slug = "denver-colorado"
  place.latitude = 39.7392
  place.longitude = -104.9903
  place.zoom_level = 12
  place.description = "Explore the diverse architecture of Denver, from historic Victorian homes to modern skyscrapers."
  place.content = <<~HTML
    <h2>Denver Architecture: A Blend of Old and New</h2>
    <p>Denver's architectural landscape reflects its rich history and rapid growth. From the Victorian-era homes in Capitol Hill to the sleek glass towers of downtown, the city showcases a fascinating mix of architectural styles.</p>
    
    <h3>Historic Districts</h3>
    <p>Denver's historic districts preserve the city's architectural heritage. The Capitol Hill neighborhood features beautiful Victorian and Queen Anne homes, while Larimer Square showcases the city's early commercial architecture.</p>
    
    <h3>Modern Developments</h3>
    <p>Recent decades have seen Denver embrace contemporary architecture, with innovative designs in the Central Business District and surrounding neighborhoods. The city's commitment to sustainable building practices is evident in many new developments.</p>
    
    <h3>Notable Buildings</h3>
    <p>Key architectural landmarks include the Colorado State Capitol, Union Station, and the Denver Art Museum's Hamilton Building. Each represents different eras and architectural philosophies that have shaped the city.</p>
  HTML
  place.published = true
  place.featured = true
  place.meta_title = "Denver Architecture Guide - Explore Colorado's Capital City"
  place.meta_description = "Discover Denver's diverse architecture, from historic Victorian homes to modern skyscrapers. Explore the city's architectural heritage and contemporary developments."
end

# Amsterdam, Netherlands
amsterdam = Place.find_or_create_by(name: "Amsterdam, Netherlands") do |place|
  place.slug = "amsterdam-netherlands"
  place.latitude = 52.3676
  place.longitude = 4.9041
  place.zoom_level = 13
  place.description = "Discover the iconic canal houses and innovative modern architecture of Amsterdam."
  place.content = <<~HTML
    <h2>Amsterdam Architecture: Canal Houses and Innovation</h2>
    <p>Amsterdam's architecture is world-renowned for its distinctive canal houses, narrow facades, and innovative use of space. The city's historic center, a UNESCO World Heritage site, showcases centuries of architectural evolution.</p>
    
    <h3>Canal Houses</h3>
    <p>The iconic canal houses along the city's historic waterways are perhaps Amsterdam's most recognizable architectural feature. These narrow, tall buildings with distinctive gables were designed to maximize space in the crowded city center.</p>
    
    <h3>Modern Architecture</h3>
    <p>Contemporary Amsterdam continues to push architectural boundaries, with innovative projects like the Eye Film Institute and the NEMO Science Museum. The city's commitment to sustainable design is evident in many recent developments.</p>
    
    <h3>Architectural Heritage</h3>
    <p>From medieval churches to Art Nouveau buildings, Amsterdam's architectural heritage spans centuries. The city's preservation efforts ensure that historic structures continue to define the urban landscape.</p>
  HTML
  place.published = true
  place.featured = true
  place.meta_title = "Amsterdam Architecture Guide - Dutch Design and Heritage"
  place.meta_description = "Explore Amsterdam's iconic canal houses, historic architecture, and innovative modern buildings. Discover the city's unique architectural heritage."
end

# New York City
nyc = Place.find_or_create_by(name: "New York City") do |place|
  place.slug = "new-york-city"
  place.latitude = 40.7128
  place.longitude = -74.0060
  place.zoom_level = 11
  place.description = "Experience the architectural diversity of New York City, from Art Deco skyscrapers to contemporary designs."
  place.content = <<~HTML
    <h2>New York City Architecture: The Skyline of Dreams</h2>
    <p>New York City's skyline is one of the most recognizable in the world, featuring iconic skyscrapers that have defined architectural trends for over a century. From the Empire State Building to the modern One World Trade Center, the city's architecture tells the story of American ambition and innovation.</p>
    
    <h3>Art Deco Masterpieces</h3>
    <p>The 1920s and 1930s brought Art Deco architecture to New York, with buildings like the Chrysler Building and the Empire State Building becoming global symbols of the city's architectural prowess.</p>
    
    <h3>Modern and Contemporary</h3>
    <p>Recent decades have seen New York embrace cutting-edge architecture, with buildings like the Guggenheim Museum and the High Line showcasing innovative design approaches. The city continues to be a laboratory for architectural experimentation.</p>
    
    <h3>Neighborhood Character</h3>
    <p>Beyond the famous skyline, New York's neighborhoods each have their own architectural character, from the brownstones of Brooklyn to the tenements of the Lower East Side.</p>
  HTML
  place.published = true
  place.featured = true
  place.meta_title = "New York City Architecture Guide - Iconic Skyline and Design"
  place.meta_description = "Explore New York City's iconic architecture, from Art Deco skyscrapers to contemporary designs. Discover the buildings that define the city's skyline."
end

puts "Created #{Place.count} places"
puts "Sample places: #{Place.pluck(:name).join(', ')}" 