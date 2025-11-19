# frozen_string_literal: true

# Used to store information about a Job
#
class ExtractionJob < ApplicationRecord
  include Job

  EXTRACTIONS_FOLDER = Rails.root.join("extractions/#{Rails.env}").to_s.freeze

  enum :kind, { full: 0, sample: 1 }, prefix: :is

  belongs_to :extraction_definition
  belongs_to :harvest_job_new, class_name: 'HarvestJob', foreign_key: :harvest_job_id, optional: true  # New relationship (for multi-item)
  has_one :harvest_job_legacy, class_name: 'HarvestJob', foreign_key: :extraction_job_id, dependent: :destroy  # Old relationship (backward compatibility)

  after_create :create_folder
  after_destroy :delete_folder

  validates :kind, presence: true, inclusion: { in: kinds.keys }, if: -> { kind.present? }

  after_create do
    self.name = "#{id}_#{kind}-extraction"
    save!
  end

  delegate :format, to: :extraction_definition
  delegate :json?, to: :extraction_definition

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

  # Returns harvest_job via either relationship (new or old)
  def harvest_job
    harvest_job_new || harvest_job_legacy
  end
end
