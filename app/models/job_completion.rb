# frozen_string_literal: true

# NOTE: This will be removed
# We are planning on creating two new fields on the extraction_definition
# We will store the stop condition name and type on the extraction_definition
class JobCompletion < ApplicationRecord
  enum :process_type, {
    extraction: 0,
    transformation: 1
  }

  belongs_to :job_completion_summary

  validates :job_id, presence: true
  validates :stop_condition_type, presence: true
  validates :stop_condition_name, presence: true
  validates :stop_condition_content, presence: true
  validates :process_type, presence: true
  validates :origin, presence: true
end
