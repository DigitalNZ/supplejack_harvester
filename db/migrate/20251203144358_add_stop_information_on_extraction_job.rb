class AddStopInformationOnExtractionJob < ActiveRecord::Migration[7.2]
  def change
    add_column :extraction_jobs, :stop_condition_type, :string
    add_column :extraction_jobs, :stop_condition_name, :string
    add_column :extraction_jobs, :stop_condition_content, :text
  end
end
