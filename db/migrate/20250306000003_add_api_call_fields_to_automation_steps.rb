# frozen_string_literal: true

class AddApiCallFieldsToAutomationSteps < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_steps, :api_url, :string
    add_column :automation_steps, :api_method, :string
    add_column :automation_steps, :api_headers, :text
    add_column :automation_steps, :api_body, :text
  end
end 