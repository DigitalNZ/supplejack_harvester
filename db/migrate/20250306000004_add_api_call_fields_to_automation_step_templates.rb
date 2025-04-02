# frozen_string_literal: true

class AddApiCallFieldsToAutomationStepTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_step_templates, :step_type, :string, default: 'pipeline', null: false
    add_column :automation_step_templates, :api_url, :string
    add_column :automation_step_templates, :api_method, :string
    add_column :automation_step_templates, :api_headers, :text
    add_column :automation_step_templates, :api_body, :text
  end
end