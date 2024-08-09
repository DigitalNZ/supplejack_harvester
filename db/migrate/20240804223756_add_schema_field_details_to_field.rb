# frozen_string_literal: true

class AddSchemaFieldDetailsToField < ActiveRecord::Migration[7.1]
  def change
    add_reference :fields, :schema_field
  end
end
