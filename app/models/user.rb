class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :screenshot_analyses
  has_many :building_analyses
  validates :handle, presence: true, uniqueness: true
  validates :public_name, presence: true

  # Callback to set default credits for free users
  before_save :set_default_credits

  # Updates to from_omniauth method
  def self.from_omniauth(auth)
    # First, attempt to find an existing user by provider and UID
    user = where(provider: auth.provider, uid: auth.uid).first

    if user.nil?
      # If no user was found by provider and UID, try to find by email
      user = where(email: auth.info.email).first

      if user
        # If found by email, update provider and uid for existing user
        user.update(provider: auth.provider, uid: auth.uid)
      else
        # For a totally new user, create with all necessary fields
        user = new(email: auth.info.email, provider: auth.provider, uid: auth.uid,
                   password: Devise.friendly_token[0, 20], # Generate a random password
                   handle: generate_unique_handle, # Ensure handle uniqueness
                   public_name: auth.info.name || generate_unique_public_name)
        # Optionally add: user.image = auth.info.image if auth.info.image
      end
    end

    # Save the user if new or changed
    user.save! if user.new_record? || user.changed?
    user
  end

  # Helper method to generate a unique handle
  def self.generate_unique_handle
    loop do
      handle = "user_#{SecureRandom.hex(4)}"
      break handle unless User.exists?(handle: handle)
    end
  end

  # Helper method to generate a unique public name
  def self.generate_unique_public_name
    "User #{SecureRandom.hex(4)}"
  end

  private

  # Sets default credits for users without an active subscription
  def set_default_credits
    self.credits ||= 5 if subscription_status != 'active'
  end

end
