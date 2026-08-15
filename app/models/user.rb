class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :screenshot_analyses
  has_many :building_analyses

  # Gamification associations
  has_many :user_achievements, dependent: :destroy
  has_many :user_style_collections, dependent: :destroy
  has_many :building_contributions, dependent: :destroy
  has_one :user_level, dependent: :destroy

  # Adjust the validations to be conditional
  validates :handle, presence: true, uniqueness: true, if: :enforce_profile_completion?
  validates :public_name, presence: true, if: :enforce_profile_completion?

  # Required on the sign-up form. The checkbox always submits "0"/"1", so an
  # unchecked box fails; OAuth signups never set the attribute (nil) and skip
  # this — their consent copy lives next to the Google button instead.
  attr_accessor :terms_of_service
  validates :terms_of_service, acceptance: { message: "must be accepted to create an account" }

  before_create :set_default_credits
  before_create :set_terms_accepted_at
  before_save :set_marketing_opted_in_at
  before_validation :assign_handle_and_public_name, on: :create

  def admin?
    admin == true
  end

  GUEST_EMAIL = 'guest@architecturehelper.com'.freeze

  # System account that owns not-yet-claimed guest trial analyses
  def self.guest
    find_by(email: GUEST_EMAIL) || begin
      u = new(email: GUEST_EMAIL, subscription_status: 'inactive')
      u.password = SecureRandom.hex(24)
      u.save!(validate: false)
      u
    end
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.public_name = auth.info.name
      user.profile_picture = auth.info.image
      user.handle = user.handle.blank? ? generate_unique_handle : user.handle
      user.public_name = user.public_name.blank? ? generate_unique_public_name : user.public_name
    end
  end

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
    # For now, always enforce profile completion
    true
  end

  private

  # Assigns a unique handle and public name if they are missing
  def assign_handle_and_public_name
    self.handle = User.generate_unique_handle if handle.blank?
    self.public_name = User.generate_unique_public_name if public_name.blank?
  end

  # Timestamps when a user opts into marketing emails
  def set_marketing_opted_in_at
    if marketing_opt_in_changed? && marketing_opt_in?
      self.marketing_opted_in_at = Time.current
    elsif marketing_opt_in_changed? && !marketing_opt_in?
      self.marketing_opted_in_at = nil
    end
  end

  # Sets default credits for users without an active subscription.
  # Assign unconditionally: the DB column default (3) means credits is never
  # nil, so a ||= here would silently keep the wrong default.
  def set_default_credits
    self.credits = 5 if subscription_status != 'active'
  end

  def set_terms_accepted_at
    self.terms_accepted_at = Time.current if ActiveModel::Type::Boolean.new.cast(terms_of_service)
  end
end
