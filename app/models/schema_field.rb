class SchemaField < ApplicationRecord
  belongs_to :schema

  enum :kind, { dynamic: 0, fixed: 1 }
end
