module ArchitectureExplorerHelper
  # Returns a thumbnail URL for S3-hosted images.
  # If a thumbnail version exists on S3, returns that URL.
  # Otherwise returns the original URL (graceful fallback).
  #
  # Thumbnail naming convention:
  #   uploads/building_123_456.jpg -> uploads/thumbs/building_123_456_400w.jpg
  #
  def thumbnail_url(image_url, width: 400)
    return image_url if image_url.blank?
    return image_url unless image_url.include?('architecture-explorer.s3')

    uri = URI.parse(image_url)
    path = uri.path.sub(/^\//, '')
    ext = File.extname(path)
    base = File.basename(path, ext)
    "https://architecture-explorer.s3.us-east-2.amazonaws.com/uploads/thumbs/#{base}_#{width}w#{ext}"
  rescue URI::InvalidURIError
    image_url
  end
end
