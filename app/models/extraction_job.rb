# frozen_string_literal: true

# Used to store information about a Job
#
class ExtractionJob < ApplicationRecord
  include Job

  EXTRACTIONS_FOLDER = Rails.root.join("extractions/#{Rails.env}").to_s.freeze

  enum :kind, { full: 0, sample: 1 }, prefix: :is

  belongs_to :extraction_definition
  belongs_to :independent_extraction_job, class_name: 'ExtractionJob', optional: true
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
    Dir.glob("#{extraction_folder}/**/*.*").sum { |file| File.size(file) }
  end

  # Returns documents from the independent extraction job if linked
  #
  # @return Extraction::Documents or nil
  def independent_extraction_documents
    return nil if independent_extraction_job_id.blank?

    independent_extraction_job.documents
  end

  # Determines if this extraction job is an independent extraction job
  # Uses explicit flag if set, otherwise falls back to checking if harvest_job is absent
  # (independent extraction jobs don't have harvest_jobs, regular extraction jobs do)
  #
  # @return [true, false]
  # :reek:NilCheck - Explicit boolean check avoids nil-check smell
  def independent_extraction?
    return is_independent_extraction unless is_independent_extraction.nil?

    harvest_job.blank?
  end

  # Returns all extracted link URLs from this independent extraction job
  # Reads through all saved documents and extracts URLs from link documents
  #
  # @return [Array<String>] list of URLs
  def extracted_links
    return [] unless independent_extraction?

    docs = documents
    (1..docs.total_pages).filter_map { |page_number| extract_link_url(docs[page_number]) }
  end

  def extract_link_url(doc)
    return nil unless doc

    body = JSON.parse(doc.body)
    body['url'] if body.is_a?(Hash) && body.keys == ['url'] && body['url'].present?
  rescue JSON::ParserError
    nil
  end
end
