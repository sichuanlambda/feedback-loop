module ArchitectureExplorerHelper
  # Returns a thumbnail URL for S3-hosted images.
  # If a thumbnail version exists on S3, returns that URL.
  # Otherwise returns the original URL (graceful fallback).
  #
  # Thumbnail naming convention:
  #   uploads/building_123_456.jpg -> uploads/thumbs/building_123_456_400w.jpg
  #
  def thumbnail_url(image_url, width: 400)
    return nil if image_url.blank?
    return image_url unless image_url.include?('architecture-explorer.s3')

    # Build thumbnail key from original
    uri = URI.parse(image_url)
    path = uri.path # e.g. /uploads/building_123_456.jpg
    ext = File.extname(path)
    base = File.basename(path, ext)
    thumb_path = "/uploads/thumbs/#{base}_#{width}w#{ext}"

    # Return thumbnail URL (same host)
    "#{uri.scheme}://#{uri.host}#{thumb_path}"
  rescue
    image_url
  end
end
