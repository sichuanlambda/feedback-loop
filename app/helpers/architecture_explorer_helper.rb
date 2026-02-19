module ArchitectureExplorerHelper
  # Returns a thumbnail URL for S3-hosted images.
  # If a thumbnail version exists on S3, returns that URL.
  # Otherwise returns the original URL (graceful fallback).
  #
  # Thumbnail naming convention:
  #   uploads/building_123_456.jpg -> uploads/thumbs/building_123_456_400w.jpg
  #
  def thumbnail_url(image_url, width: 400)
    # Thumbnails not yet generated for all buildings — return original URL for now.
    # Once rake images:generate_thumbnails has run, re-enable thumbnail logic.
    image_url
  end
end
