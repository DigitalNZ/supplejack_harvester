# frozen_string_literal: true

# Every job, whatever ran it. One pipeline's are PipelineJobsController's, and both draw
# the same table from the same filters - see ApplicationController#paginate_and_filter_jobs
# and PipelineJob.for_jobs_table.
class JobsController < ApplicationController
  def index
    @pipeline_jobs = paginate_and_filter_jobs(PipelineJob.for_jobs_table)
  end
end
