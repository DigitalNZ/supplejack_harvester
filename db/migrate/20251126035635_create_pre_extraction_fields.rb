# frozen_string_literal: true

class CreatePreExtractionFields < ActiveRecord::Migration[7.2]
  def change
    # Extraction definitions
    add_column :extraction_definitions, :pre_extraction, :boolean, default: false, null: false
    add_column :extraction_definitions, :link_selector, :string

    # Extraction jobs - link to pre-extraction job
    add_column :extraction_jobs, :pre_extraction_job_id, :bigint
    add_index :extraction_jobs, :pre_extraction_job_id

    # Automation steps - for pre-extraction step type
    add_column :automation_steps, :extraction_definition_id, :bigint
    add_column :automation_steps, :pre_extraction_job_id, :bigint
    add_index :automation_steps, :extraction_definition_id
    add_index :automation_steps, :pre_extraction_job_id
  end
end
