# frozen_string_literal: true

class LoadWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  # How many times a batch is handed to the destination before it is given up on, and how
  # long to wait before each further attempt. Retriable covers the destination being slow;
  # these cover it being gone - a restarting or refusing API is unavailable for longer than
  # any in-process backoff can sensibly wait out.
  MAX_BATCH_ATTEMPTS = 3
  RETRY_DELAYS = [5.minutes, 15.minutes].freeze

  # Failures a second attempt cannot improve on: a refusal the destination will repeat however
  # many times it is asked, and a read timeout - it had the batch when the socket gave up and
  # may well go on to accept it, so sending it again only repeats an expensive write against an
  # endpoint that was already too slow to answer. Neither is retried in process nor requeued.
  #
  # Faraday::TimeoutError is the request having been sent and not answered. A connection that
  # never opened, was refused, or broke mid-response arrives as ConnectionFailed and is still
  # worth resending, because the destination certainly never had it.
  POINTLESS_TO_RESEND = [Load::PermanentError, Faraday::TimeoutError].freeze

  # Named for the Retriable option it is passed as, which re-raises at once when this is false
  # rather than working through the backoff.
  RETRY_IF = ->(error) { POINTLESS_TO_RESEND.none? { |kind| error.is_a?(kind) } }

  # Sidekiq builds one of these per job with no arguments and calls #perform, so every
  # instance variable below is really set in #prepare. Declaring them here says what state a
  # worker holds without having to read #perform to find out.
  def initialize
    super
    @harvest_job = nil
    @harvest_report = nil
    @api_record_id = nil
    @attempt = 1
    @abandoned_batches = 0
  end

  def perform(harvest_job_id, records, api_record_id = nil, attempt = 1)
    prepare(harvest_job_id, api_record_id, attempt)

    job_start
    transformed_records = JSON.parse(records)

    transformed_records.each_slice(batch_size) do |batch|
      @harvest_job.reload

      break if @harvest_job.cancelled? || @harvest_job.pipeline_job.cancelled?

      process_batch(batch)
    end
    job_end
  end

  def prepare(harvest_job_id, api_record_id, attempt)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @harvest_report = @harvest_job.harvest_report
    @api_record_id = api_record_id
    @attempt = attempt
    @abandoned_batches = 0
  end

  def log_retry_attempt
    proc do |exception, try, elapsed_time, next_interval|
      logger.info(
        "#{exception.class}: '#{exception.message}':" \
        "#{try} tries in #{elapsed_time} seconds and" \
        "#{next_interval} seconds until the next try."
      )
    end
  end

  # A batch the destination would not take is that batch's failure, not this worker's. The
  # slices after it are still loadable and the report still has to reach a terminal state,
  # so the failure is handled and the loop carries on. Re-raising here skipped #job_end,
  # which left the block's load counted one worker short and stuck on "running" for good -
  # and took every remaining slice in this worker's page down with it.
  def process_batch(batch)
    ::Retriable.with_context(:load, on_retry: log_retry_attempt, retry_if: RETRY_IF) do
      execute_load(batch)
    end
  rescue StandardError => e
    handle_load_error(batch, e)
  end

  def execute_load(batch)
    Load::Execution.new(batch, @harvest_job, @api_record_id).call
    @harvest_report.increment_records_loaded!(batch.count)
    @harvest_report.update(load_updated_time: Time.zone.now)
  end

  # The batch is requeued rather than dropped while it has attempts left: Retriable spans
  # minutes, which is no help when the destination is unavailable for longer than that, and
  # a dropped batch is records lost rather than records delayed. Only a batch that has run
  # out of attempts is recorded as an error and counted against the report.
  def handle_load_error(batch, error)
    logger.info "Load Excecution error (attempt #{@attempt}/#{MAX_BATCH_ATTEMPTS}): #{error}"

    return requeue_batch(batch) if requeue?(error)

    @abandoned_batches += 1
    record_load_error(error)
  end

  # Nothing POINTLESS_TO_RESEND covers is requeued either. On staging a page that timed out at
  # 60 seconds was written by the API 13 seconds later and answered 200 to nobody, so the two
  # requeues that followed bought nothing but the same 550KB write twice more.
  def requeue?(error)
    return false if POINTLESS_TO_RESEND.any? { |kind| error.is_a?(kind) }

    @attempt < MAX_BATCH_ATTEMPTS
  end

  # Never 0: each_slice(0) raises, and a block that has no load definition yet reads its
  # fallback through HarvestDefinition#load_batch_size.
  def batch_size = [@harvest_job.harvest_definition.load_batch_size.to_i, 1].max

  # The retry is a load worker of its own, so the report has to be told to expect it.
  # HarvestReport#load_workers_completed? compares queued against completed, so a retry that
  # counted itself completed without having been queued would push completed past queued and
  # the equality could never come true again.
  def requeue_batch(batch)
    @harvest_report.increment_load_workers_queued!

    self.class.perform_in_with_priority(
      @harvest_job.pipeline_job.job_priority,
      RETRY_DELAYS[@attempt - 1],
      @harvest_job.id,
      batch.to_json,
      @api_record_id,
      @attempt + 1
    )
  end

  def record_load_error(error)
    JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                           error: error,
                                                                           definition:
                                                                             @harvest_job&.extraction_definition,
                                                                           job: @harvest_job&.extraction_job,
                                                                           origin: 'LoadWorker'
                                                                         })
  end

  def job_start
    @harvest_report.load_running!
  end

  def job_end
    pipeline_job = @harvest_job.pipeline_job
    @harvest_report.increment_load_workers_completed!
    @harvest_report.reload

    # The completion runs even when batches were abandoned: it is what tells the destination
    # the source is no longer harvesting, and leaving that flag set is worse than a load
    # marked errored. Marking errored afterwards is what stops the run reporting that it
    # loaded everything - Load::Completion treats an errored load as already marked, so no
    # later worker flips it back.
    @harvest_job.complete_load(@harvest_report)
    @harvest_report.load_errored! if @abandoned_batches.positive?

    pipeline_job.enqueue_enrichment_jobs(@harvest_job.name)
    @harvest_job.execute_delete_previous_records

    return unless pipeline_job.reload.finished?

    pipeline_job.completed!
  end
end
