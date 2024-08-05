# frozen_string_literal: true

class Schema < ApplicationRecord
  has_many :schema_fields, dependent: :destroy
  belongs_to :last_edited_by, class_name: 'User', optional: true

  validates :name, presence: true

  def to_h
    {
      id:,
      name:,
      fields: schema_fields.map(&:to_h),
      created_at:,
      updated_at: 
    }
  end
end
