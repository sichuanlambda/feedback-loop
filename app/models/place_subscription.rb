class PlaceSubscription < ApplicationRecord
  belongs_to :place

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :place_id, message: "is already subscribed to this place" }
end
