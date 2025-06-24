# Place Content Generation System

This document outlines the automated content and image generation system for place pages in the architecture explorer.

## Overview

The system provides multiple approaches to generate high-quality content and images for place pages at scale:

1. **AI-Generated Content** - Automated content creation using GPT
2. **External API Images** - High-quality photos from Unsplash
3. **Building Analysis Aggregation** - Real photos from analyzed buildings
4. **Manual Override** - Admin ability to upload custom content

## Database Schema

### New Fields Added to Places Table

- `hero_image_url` - URL for the main hero image
- `hero_image_alt` - Alt text for accessibility
- `representative_image_url` - Fallback image from building analyses
- `content_generated_at` - Timestamp when content was last generated
- `image_source` - Source of the hero image (placeholder, unsplash, building_analysis, ai_generated, external)

## Components

### 1. PlaceContentGenerator Service

Located in `app/services/place_content_generator.rb`

**Features:**
- Generates content using AI (GPT integration)
- Fetches images from Unsplash API
- Falls back to building analysis images
- Creates fallback content when AI is unavailable

**Usage:**
```ruby
generator = PlaceContentGenerator.new(place)
generator.generate_content_and_images
```

### 2. GeneratePlaceContentJob

Background job for asynchronous content generation.

**Features:**
- Runs content generation in background
- Handles errors gracefully
- Logs progress and issues

**Usage:**
```ruby
GeneratePlaceContentJob.perform_later(place.id)
```

### 3. Enhanced Place Model

New methods added to `app/models/place.rb`:

- `has_hero_image?` - Check if place has a hero image
- `has_content?` - Check if place has content
- `needs_content_generation?` - Check if content needs to be generated
- `needs_image_generation?` - Check if image needs to be generated
- `building_analyses_in_place` - Get buildings within place boundaries
- `best_representative_image` - Get best available image
- `architectural_styles_summary` - Get style frequency from buildings

## Usage

### 1. Automatic Generation

Content is automatically generated when:
- A new place is created
- Admin manually triggers generation
- Background job processes queued places

### 2. Manual Generation

**Via Admin Interface:**
1. Go to Admin > Places
2. Edit a place
3. Click "Generate Content" button in the Content section

**Via Rake Tasks:**
```bash
# Generate content for all places that need it
rails places:generate_content

# Generate content for specific place
rails places:generate_for_place[123]

# List places needing content
rails places:list_needing_content
```

**Via Rails Console:**
```ruby
place = Place.find(123)
GeneratePlaceContentJob.perform_now(place.id)
```

### 3. Manual Override

Admins can manually set:
- Hero image URL
- Alt text
- Representative image URL
- Image source
- Full content

## Image Sources Priority

The system tries image sources in this order:

1. **Manual Upload** - Admin-provided hero image
2. **Unsplash API** - High-quality architectural photos
3. **Building Analysis** - Real photos from analyzed buildings
4. **AI Generated** - Generated images (future feature)
5. **Placeholder** - Default icon and text

## Content Generation Process

1. **Analyze Existing Buildings** - Get architectural styles from building analyses
2. **Generate Content** - Use AI to create comprehensive content
3. **Fallback Content** - Use template if AI is unavailable
4. **Find Images** - Try multiple image sources
5. **Update Place** - Save generated content and images

## Configuration

### Unsplash API

Add to `config/credentials.yml.enc`:
```yaml
unsplash:
  access_key: your_unsplash_access_key
```

### GPT Integration

The system is designed to integrate with your existing GPT service. Update the `generate_content_with_ai` method in `PlaceContentGenerator` to use your GPT service.

## Monitoring

### Logs

Content generation is logged with:
- Success/failure status
- Error messages
- Processing time

### Admin Dashboard

The admin interface shows:
- Content generation status
- Image source information
- Generation timestamps

## Future Enhancements

### 1. AI Image Generation

Integrate with:
- DALL-E API
- Stable Diffusion
- Midjourney API

### 2. Content Quality Scoring

- Rate generated content quality
- A/B test different prompts
- User feedback integration

### 3. Community Contributions

- User-submitted photos
- Voting system
- Moderation queue

### 4. Advanced Image Processing

- Image optimization
- Multiple image sizes
- CDN integration

## Troubleshooting

### Common Issues

1. **No Images Generated**
   - Check Unsplash API credentials
   - Verify building analyses have images
   - Check network connectivity

2. **Content Not Generated**
   - Verify GPT service integration
   - Check background job queue
   - Review error logs

3. **Poor Image Quality**
   - Adjust Unsplash search queries
   - Review building analysis image quality
   - Consider manual image upload

### Debug Commands

```bash
# Check place status
rails runner "Place.find(123).needs_content_generation?"

# Test content generator
rails runner "PlaceContentGenerator.new(Place.find(123)).generate_content_and_images"

# Check background jobs
rails runner "puts Delayed::Job.count"
```

## Performance Considerations

- Content generation is asynchronous
- Rate limiting prevents API abuse
- Images are cached and optimized
- Background jobs handle high load

## Security

- API keys stored in credentials
- Input sanitization for content
- Image URL validation
- Admin-only access to generation controls 