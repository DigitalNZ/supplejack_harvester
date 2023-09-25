# frozen_string_literal: true

class CreateRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :requests, &:timestamps

    add_reference :requests, :extraction_definition, null: false
  end
end
