class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :screenshot_analyses
  has_many :building_analyses
  validates :handle, presence: true, uniqueness: true
  validates :public_name, presence: true
end
