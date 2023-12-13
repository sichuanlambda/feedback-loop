class DogRating < ApplicationRecord
  validates :image, presence: true  # changed from image_url to image
  validates :caption, presence: true
end
