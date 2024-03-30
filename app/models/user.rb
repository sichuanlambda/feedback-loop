class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :screenshot_analyses
  has_many :building_analyses

  # Adjust the validations to be conditional
  validates :handle, presence: true, uniqueness: true, if: :enforce_profile_completion?
  validates :public_name, presence: true, if: :enforce_profile_completion?

  before_create :set_default_credits
  # Assuming you keep the callback for assigning handle and public name at creation
  before_validation :assign_handle_and_public_name, on: :create

  def self.generate_unique_handle
    loop do
      handle = "user_#{SecureRandom.hex(4)}"
      break handle unless User.exists?(handle: handle)
    end
  end

  def self.generate_unique_public_name
    "User #{SecureRandom.hex(4)}"
  end

  def enforce_profile_completion?
    # Logic to determine if profile completion enforcement is necessary
    !new_record? && completed_profile_at.blank?
  end

  private

  # Assigns a unique handle and public name if they are missing
  def assign_handle_and_public_name
    self.handle = User.generate_unique_handle if handle.blank?
    self.public_name = User.generate_unique_public_name if public_name.blank?
  end

  # Sets default credits for users without an active subscription
  def set_default_credits
    self.credits ||= 5 if subscription_status != 'active'
  end

  # Optionally, track when a user has completed their profile
  # This could be an attribute of the User model: completed_profile_at:datetime
  # Update this attribute when the user completes their profile
end
