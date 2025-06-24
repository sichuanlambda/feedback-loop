# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://app.architecturehelper.com"

# Generate both compressed and uncompressed sitemaps
SitemapGenerator::Sitemap.create_index = true

SitemapGenerator::Sitemap.create do
  # Add static pages
  add root_path, :changefreq => 'daily', :priority => 1.0
  add '/architecture_explorer', :changefreq => 'weekly', :priority => 0.8
  add '/architecture_designer', :changefreq => 'weekly', :priority => 0.8
  add '/feedbacks', :changefreq => 'weekly', :priority => 0.7
  add '/pages/home', :changefreq => 'monthly', :priority => 0.6
  
  # Add all published places
  Place.where(published: true).find_each do |place|
    add place_path(place), 
        :lastmod => place.updated_at,
        :changefreq => 'weekly',
        :priority => 0.8
  end
  
  # Add building analysis pages (if they're public)
  BuildingAnalysis.where(visible_in_library: true).find_each do |building|
    add architecture_explorer_show_path(building), 
        :lastmod => building.updated_at,
        :changefreq => 'monthly',
        :priority => 0.6
  end
end 