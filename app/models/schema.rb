# frozen_string_literal: true

class Schema < ApplicationRecord
  has_many :schema_fields, dependent: :destroy
  belongs_to :last_edited_by, class_name: 'User', optional: true

  validates :name, presence: true

  def to_h
    {
      id:,
      name:,
      schema_field_ids: schema_fields.map(&:id),
      created_at:,
      updated_at: 
    }
  end
end
