# frozen_string_literal: true

class JobsController < ApplicationController
  def index
    @pipeline_jobs = paginate_and_filter_jobs(PipelineJob.all)
  end
end
