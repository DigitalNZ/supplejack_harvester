# frozen_string_literal: true

class Schema < ApplicationRecord
  has_many :schema_fields

  validates :name, presence: true
end
