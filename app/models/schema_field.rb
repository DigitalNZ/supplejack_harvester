class SchemaField < ApplicationRecord
  belongs_to :schema

  enum :kind, { dynamic: 0, fixed: 1 }

  def to_h
    {
      id:,
      name:,
      kind:,
      created_at:,
      updated_at:
    }
  end
end
