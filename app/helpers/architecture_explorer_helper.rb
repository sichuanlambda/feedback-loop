module ArchitectureExplorerHelper
  def thumbnail_url(image_url, width: 400)
    return image_url unless image_url.present? && image_url.include?('architecture-explorer.s3')
    return image_url if image_url.match?(/\.(php|pdf|tif|svg)(\?|$)/i)

    # Extract filename and build thumb path
    uri = URI.parse(image_url)
    path = uri.path  # e.g. /uploads/building_123.jpg
    ext = File.extname(path)
    base = File.basename(path, ext)
    dir = File.dirname(path)

    thumb_path = "#{dir}/thumbs/#{base}_#{width}w.jpg"
    "https://architecture-explorer.s3.us-east-2.amazonaws.com#{thumb_path}"
  end
end
