# Set the host name for URL creation. CANONICAL_HOST lets the domain flip
# (app.architecturehelper.com -> architecturehelper.com) without a code change.
SitemapGenerator::Sitemap.default_host = ENV.fetch('CANONICAL_HOST', 'https://app.architecturehelper.com')

# Generate both compressed and uncompressed sitemaps
SitemapGenerator::Sitemap.create_index = true

SitemapGenerator::Sitemap.create do
  # Add static pages
  add root_path, :changefreq => 'daily', :priority => 1.0
  add '/architecture_explorer/new', :changefreq => 'weekly', :priority => 0.8
  add '/pricing', :changefreq => 'weekly', :priority => 0.9
  add '/restyle', :changefreq => 'weekly', :priority => 0.8
  add '/style-finder', :changefreq => 'monthly', :priority => 0.6
  add '/building_library', :changefreq => 'daily', :priority => 0.8

  # Blog (recovered architecturehelper.com/blog content)
  add '/blog', :changefreq => 'weekly', :priority => 0.8
  BlogPost.published.find_each do |post|
    add "/blog/#{post.slug}",
        :lastmod => post.updated_at,
        :changefreq => 'monthly',
        :priority => 0.7
  end

  # Style pages (programmatic SEO)
  add '/styles', :changefreq => 'weekly', :priority => 0.8
  style_names = Set.new
  BuildingAnalysis.where(visible_in_library: true).pluck(:h3_contents).compact.each do |h3_content|
    StyleNormalizer.normalize_array(JSON.parse(h3_content)).each { |s| style_names << s }
  rescue JSON::ParserError
    next
  end
  style_names.each do |style|
    slug = style.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+$/, '')
    add "/building_library/styles/#{slug}", :changefreq => 'weekly', :priority => 0.7
  end

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
