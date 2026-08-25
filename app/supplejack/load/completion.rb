# frozen_string_literal: true

module Load
  # A block's last load finishing.
  #
  # The destination flags a source as harvesting when the block queues its first load
  # (TransformationWorker#notify_harvesting), and leaves its records alone while that flag is
  # set - so clearing it belongs with the load status being marked completed, and the two must
  # not come apart. They did: LoadWorker was the only one that cleared the flag, and it only
  # gets the chance when the loads finish after the extraction, because
  # HarvestReport#load_workers_completed? wants the transformation completed first. On a harvest
  # whose loads keep up with its pages every load worker stands aside, another worker marks the
  # load completed, and the source was left on harvesting: true for good.
  class Completion
    def initialize(harvest_job, report)
      @harvest_job = harvest_job
      @report = report
    end

    # Only the caller that finds the load finished and still unmarked does anything, so the
    # destination is not told again by the next worker through here.
    def call
      return unless @report.load_workers_completed?
      return if @report.load_completed?

      @report.load_completed!
      notify_harvesting_finished
    end

    private

    # A block that queued no loads never told the destination harvesting had begun - a
    # pre-processing block feeding a file, a harvest that matched no records - so it has
    # nothing to take back.
    def notify_harvesting_finished
      return if @report.load_workers_queued.zero?

      harvested_source_id = source_id
      return if harvested_source_id.blank?

      tell_destination(harvested_source_id)
    end

    def tell_destination(harvested_source_id)
      ::Retriable.retriable do
        Api::Utils::NotifyHarvesting.new(destination, harvested_source_id, false).call
      end
    rescue StandardError => e
      Rails.logger.info "Load::Completion: API Utils NotifyHarvesting error: #{e.message}"
    end

    # See TransformationWorker#source_id - the pipeline's harvest block, not whichever
    # definition happens to have the lowest id.
    def source_id = pipeline_job.pipeline.harvest&.source_id

    def destination = pipeline_job.destination

    def pipeline_job = @harvest_job.pipeline_job
  end
end
