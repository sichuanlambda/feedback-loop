class Feedback < ApplicationRecord
  belongs_to :gpt_interaction, optional: true
  attr_accessor :comment
end
