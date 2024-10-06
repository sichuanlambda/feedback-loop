require "image_processing/mini_magick"

ImageProcessing::MiniMagick.configure do |config|
  config.pngcrush = false
  config.pngout = false
  config.advpng = false
  config.oxipng = false
  config.jhead = false
  config.svgo = false
end
