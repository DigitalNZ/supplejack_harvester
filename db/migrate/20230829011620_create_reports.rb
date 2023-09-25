# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :harvest_reports do |t|
      t.integer   'extraction_status', default: 0
      t.timestamp 'extraction_start_time'
      t.timestamp 'extraction_end_time'
      t.integer   'transformation_status', default: 0
      t.timestamp 'transformation_start_time'
      t.timestamp 'transformation_end_time'
      t.integer   'load_status', default: 0
      t.timestamp 'load_start_time'
      t.timestamp 'load_end_time'
      t.integer   'pages_extracted',     default: 0, null: false
      t.integer   'records_transformed', default: 0, null: false
      t.integer   'records_loaded',      default: 0, null: false
      t.integer   'records_rejected',    default: 0, null: false
      t.integer   'records_deleted',     default: 0, null: false
      t.text      'name'

      t.timestamps
    end
  end
end
