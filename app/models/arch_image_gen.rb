class ArchImageGen < ApplicationRecord
  belongs_to :user, optional: true

  scope :restyles, -> { where(kind: 'restyle') }
  scope :complete, -> { where(status: 'complete') }

  def restyle?
    kind == 'restyle'
  end
end
