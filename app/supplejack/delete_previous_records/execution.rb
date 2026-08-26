# frozen_string_literal: true

module DeletePreviousRecords
  class Execution
    def initialize(source_id, job_id, destination)
      @source_id = source_id
      @job_id = job_id
      @destination = destination
    end

    # A whole-source flush is the slowest request this app makes of the destination, which
    # makes it the likeliest to time out - and it must not take its caller down with it. Both
    # callers have work left to do after it: LoadWorker#job_end still has the run to finish,
    # and HarvestJob#trigger_following_processes still has the chain to advance. A run left
    # on "running" for good is worse than previous records left behind, and those are not
    # left for long: the flush matches every record of the source not tagged with the given
    # job_id, so the next run that reaches this point clears whatever this one could not.
    #
    # Deliberately a single attempt. Retriable's configuration spans up to 15 minutes, which
    # is a long time to hold a Sidekiq thread for a request the next run will make anyway.
    def call
      flush
    rescue StandardError => e
      Rails.logger.info(
        "DeletePreviousRecords::Execution: flush of #{@source_id} for job #{@job_id} failed: #{e.message}"
      )
      nil
    end

    private

    def flush
      Api::Harvester::Record.new(@destination).flush(
        source_id: @source_id,
        job_id: @job_id
      )
    end
  end
end
