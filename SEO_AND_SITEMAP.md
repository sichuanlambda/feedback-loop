# SEO and Sitemap Features

This document explains the SEO and sitemap features implemented for place pages.

## SEO Meta Information

### Automatic Generation
When content is generated for a place, the system automatically creates:
- **Meta Title**: Includes place name and primary architectural styles
- **Meta Description**: Describes the place, building count, and architectural styles

### Manual Generation
You can manually generate SEO meta information:

```ruby
# Via Rails console
place = Place.find_by(name: "Denver")
PlaceContentGenerator.new(place).generate_seo_meta

# Via rake task
rake places:generate_content[place_id]
```

### Meta Information Format
- **Meta Title**: `"{Place Name} Architecture Guide - {Style1} & {Style2} Styles"`
- **Meta Description**: `"Explore the architecture of {Place Name}. Discover {X} analyzed buildings featuring {Style1}, {Style2}, {Style3} styles. Get insights into local architectural heritage and contemporary design."`

## Sitemap Management

### Automatic Updates
The sitemap is automatically updated when:
- A place is published/unpublished
- New places are created via auto-generation
- Places are updated in the admin interface

### Manual Sitemap Generation

```bash
# Generate sitemap
bundle exec rake sitemap:generate

# Generate sitemap and ping search engines
bundle exec rake sitemap:ping

# Update sitemap for specific place
bundle exec rake sitemap:update_place[123]
```

### Sitemap Contents
The sitemap includes:
- **Static Pages**: Home, architecture explorer, designer, feedbacks
- **Published Places**: All published place pages with weekly update frequency
- **Building Analyses**: Public building analysis pages with monthly update frequency

### Sitemap Configuration
- **Location**: `/public/sitemap.xml.gz` (compressed)
- **Update Frequency**: 
  - Places: Weekly
  - Building analyses: Monthly
  - Static pages: Daily to Monthly
- **Priority**: 
  - Home page: 1.0
  - Places: 0.8
  - Building analyses: 0.6

## Robots.txt

The robots.txt file includes:
- Sitemap location reference
- Disallow rules for admin, users, and API areas
- Allow rules for public content

## Usage Examples

### Generate Content with SEO for a Place
```ruby
# Via admin interface
# 1. Go to /admin/places
# 2. Click "Generate Content" for a place
# 3. Content and SEO meta will be generated automatically

# Via Rails console
place = Place.find_by(name: "Denver")
PlaceContentGenerator.new(place).generate_content_and_images
```

### Update Domain in Sitemap
Edit `config/sitemap.rb` and change:
```ruby
SitemapGenerator::Sitemap.default_host = "https://yourdomain.com"
```

### Check Sitemap Status
```bash
# View sitemap contents
gunzip -c public/sitemap.xml.gz

# Check sitemap statistics
bundle exec rake sitemap:generate
```

## Background Jobs

The system uses background jobs for:
- **UpdateSitemapJob**: Updates sitemap when places are published/unpublished
- **GeneratePlaceContentJob**: Generates content and SEO meta for places

## Monitoring

Check the logs for sitemap updates:
```bash
tail -f log/development.log | grep "Sitemap"
```

## Best Practices

1. **Always publish places** to include them in the sitemap
2. **Generate content** for better SEO meta information
3. **Update sitemap** after bulk place creation
4. **Monitor search console** for sitemap indexing status
5. **Use descriptive place names** for better SEO titles 