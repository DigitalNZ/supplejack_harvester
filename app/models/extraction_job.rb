# frozen_string_literal: true

# Used to store information about a Job
#
class ExtractionJob < ApplicationRecord
  include Job

  EXTRACTIONS_FOLDER = Rails.root.join("extractions/#{Rails.env}").to_s.freeze

  enum :kind, { full: 0, sample: 1 }, prefix: :is

  belongs_to :extraction_definition
  belongs_to :source_pipeline_job, class_name: 'PipelineJob', optional: true
  has_one :harvest_job, dependent: :destroy

  after_create :create_folder
  after_destroy :delete_folder

  validates :kind, presence: true, inclusion: { in: kinds.keys }, if: -> { kind.present? }

  after_create do
    self.name = "#{id}_#{kind}-extraction"
    save!
  end

  delegate :format, to: :extraction_definition
  delegate :json?, to: :extraction_definition

  # A job started on its own, from a block's dropdown rather than a pipeline run, that
  # was given an earlier run's pre-processed records to work from. A job belonging to a
  # pipeline run gets its records through its harvest job instead.
  def iterates_preprocess_output?
    source_pipeline_job_id.present? && source_position.present?
  end

  # The folder holding the records this job iterates.
  def preprocess_output_folder
    return unless iterates_preprocess_output?

    PreProcess::Output.folder(source_pipeline_job_id, source_position)
  end

  # Returns the fullpath to the extraction folder for this job
  #
  # @example job.extraction_folder #=> /app/extractions/development/2023-04-28_08-51-16_-_19
  # @return String
  def extraction_folder
    "#{EXTRACTIONS_FOLDER}/#{created_at.to_fs(:file_format)}_-_#{id}"
  end

  # Creates a folder at the location of the extraction_folder
  #
  # @return [true, false] depending on success of the folder creation
  def create_folder
    return if Dir.exist?(extraction_folder)

    Dir.mkdir(extraction_folder)
  end

  # Deletes a folder at the location of the extraction folder
  #
  # @return [true, false] depending on success of the folder deletion
  def delete_folder
    return unless Dir.exist?(extraction_folder)

    FileUtils.rm_rf Dir.glob("#{extraction_folder}/*")
    Dir.rmdir(extraction_folder)
  end

  # Converts the files stored in the extraction folder into pageable objects
  #
  # @return Extraction::Documents object
  def documents
    Extraction::Documents.new(extraction_folder)
  end

  # Returns the size of the extraction folder in bytes
  #
  # @return Integer
  def extraction_folder_size_in_bytes
    Dir.glob("#{extraction_folder}/**/*.*").sum { |f| File.size(f) }
  end

  # Records the stop condition that ended this extraction, if any.
  #
  # @param type [String] who set the stop condition (system/user)
  # @param name [String] identifier for the condition
  # @param content [String] optional description or script
  def record_stop_condition(type:, name:, content:)
    update!(
      stop_condition_type: type,
      stop_condition_name: name,
      stop_condition_content: content
    )
  end
end
