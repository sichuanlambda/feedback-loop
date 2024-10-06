require "image_processing/mini_magick"
require 'image_optim'

# Configure ImageProcessing::MiniMagick
ImageProcessing::MiniMagick.configure do |config|
  # No need to configure these options for ImageProcessing::MiniMagick
  # Remove or comment out these lines
  # config.pngcrush = false
  # config.pngout = false
  # config.advpng = false
  # config.oxipng = false
  # config.jhead = false
  # config.svgo = false
end

# Create an instance of ImageOptim with the desired configuration
IMAGE_OPTIM = ImageOptim.new(
  nice: 20,
  skip_missing_workers: true,
  pngcrush: false,
  pngout: false,
  advpng: false,
  optipng: false,
  oxipng: false,
  jhead: false,
  jpegoptim: false,
  gifsicle: false,
  svgo: false
)
