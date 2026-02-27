module ArchitectureExplorerHelper
  # Returns a thumbnail URL for S3-hosted images.
  # If a thumbnail version exists on S3, returns that URL.
  # Otherwise returns the original URL (graceful fallback).
  #
  # Thumbnail naming convention:
  #   uploads/building_123_456.jpg -> uploads/thumbs/building_123_456_400w.jpg
  #
  def thumbnail_url(image_url, width: 400)
    # Thumbnail system disabled — thumbnails were never generated on S3,
    # and the old logic collapsed all "original.jpg" filenames to the same path.
    # Just return the original URL until a proper thumbnail pipeline is built.
    image_url
  end
end
