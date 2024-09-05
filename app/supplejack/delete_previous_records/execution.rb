# frozen_string_literal: true

module DeletePreviousRecords
  class Execution
    def initialize(source_id, job_id, destination)
      @source_id = source_id
      @job_id = job_id
      @destination = destination
    end

    def call
      Api::Harvester::Record.new(@destination).flush(
        source_id: @source_id,
        job_id: @job_id
      )
    end
  end
end
