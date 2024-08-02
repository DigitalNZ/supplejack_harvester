# frozen_string_literal: true

class Schema < ApplicationRecord
  has_many :schema_fields, dependent: :destroy
  belongs_to :last_edited_by, class_name: 'User', optional: true

  validates :name, presence: true
end
