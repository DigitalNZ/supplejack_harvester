# frozen_string_literal: true

class CreateApiResponseReports < ActiveRecord::Migration[7.1]
  def change
    create_table :api_response_reports do |t|
      t.references :automation_step, null: false, foreign_key: true
      t.string :status, null: false, default: 'not_started'
      t.integer :response_code
      t.text :response_body
      t.text :response_headers
      t.datetime :executed_at
      
      t.timestamps
    end
  end
end 