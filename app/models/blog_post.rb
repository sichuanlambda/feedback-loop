class BlogPost < ApplicationRecord
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :title, presence: true

  scope :published, -> { where(published: true).order(published_at: :desc, id: :desc) }

  def to_param
    slug
  end
end
