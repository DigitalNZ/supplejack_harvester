# frozen_string_literal: true

class JobsController < ApplicationController
  def index
    # The rows carry each pipeline's tags, so they are loaded with the pipelines rather
    # than a query at a time as the table is drawn.
    @pipeline_jobs = paginate_and_filter_jobs(PipelineJob.includes([:harvest_reports, :destination, :schedule,
                                                                    { pipeline: :tags },
                                                                    { automation_step: [:automation] }]))

    respond_to do |format|
      format.html
      format.js
    end
  end
end
