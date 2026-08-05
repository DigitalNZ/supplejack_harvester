# frozen_string_literal: true

# Used to store information about a Job
#
class ExtractionJob < ApplicationRecord
  include Job

  EXTRACTIONS_FOLDER = Rails.root.join("extractions/#{Rails.env}").to_s.freeze
  UNFINISHED_STATUSES = %w[queued running].freeze

  enum :kind, { full: 0, sample: 1 }, prefix: :is

  belongs_to :extraction_definition
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

  # Deletes a folder at the location of the extraction folder.
  #
  # Removes the folder itself rather than globbing its contents first: a glob
  # skips dotfiles, so a stray .DS_Store used to leave the folder behind and
  # Dir.rmdir raised Errno::ENOTEMPTY.
  #
  # @return Array the paths removed
  def delete_folder
    return unless Dir.exist?(extraction_folder)

    FileUtils.rm_rf(extraction_folder)
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

  # Removes the extracted data from disk while keeping the job row, so run
  # history and anything pointing at this job survive. Safe to call when the
  # folder is already missing.
  def purge!
    delete_folder
    update!(purged_at: Time.zone.now)
  end

  # True once the extracted data has been removed from disk by the retention
  # policy. The job row itself still exists.
  def purged?
    purged_at.present?
  end

  # Extraction jobs whose data is old enough to delete under the retention
  # policy, oldest first.
  #
  # The ranking runs over every job that still has data, whatever its status:
  # filtering before ranking would let a running job shift every index by one.
  # Exclusions are applied to the ranked set.
  #
  # @return ActiveRecord::Relation
  def self.purge_candidates(policy)
    eligible_for_purge(policy)
      .where(beyond_retention, keep: policy.keep_latest,
                               pinned: pinned_ids.presence || [0],
                               max_age: policy.max_age_cutoff)
      .order(:created_at, :id)
      .limit(policy.batch_limit)
  end

  class << self
    private

    # The ranked, status-and-exclusion-filtered set purge_candidates chooses
    # from, before the keep_latest/max_age retention clause is applied.
    def eligible_for_purge(policy)
      from(ranked_by_recency, :extraction_jobs)
        .where(status: Job::FINISHED_STATUSES)
        .where.not(extraction_definition_id: policy.excluded_extraction_definition_ids)
        .where.not(id: busy_ids)
        .where(created_at: ...policy.min_age_cutoff)
    end

    # Numbers each definition's surviving extractions, 1 being the newest.
    def ranked_by_recency
      select(
        'extraction_jobs.*',
        'ROW_NUMBER() OVER (PARTITION BY extraction_definition_id ' \
        'ORDER BY created_at DESC, id DESC) AS extraction_index'
      ).where(purged_at: nil)
    end

    # Dan's rule: past the newest N for its definition, or simply too old. A job a
    # transformation definition previews from is spared the first clause but not
    # the second.
    def beyond_retention
      '(extraction_index > :keep AND extraction_jobs.id NOT IN (:pinned)) OR created_at < :max_age'
    end

    # Extraction jobs a transformation definition renders its preview from.
    def pinned_ids
      TransformationDefinition.distinct.pluck(:extraction_job_id).compact
    end

    # Extraction jobs that work still in flight is reading. A pipeline job's
    # status stays NULL until PipelineWorker picks it up (the column has no
    # default), so NULL counts as busy.
    def busy_ids
      (HarvestJob.where(status: UNFINISHED_STATUSES).pluck(:extraction_job_id) +
        PipelineJob.where(status: UNFINISHED_STATUSES + [nil]).pluck(:extraction_job_id)).compact
    end
  end
end
