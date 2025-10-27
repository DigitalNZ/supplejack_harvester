# frozen_string_literal: true

class JobsController < ApplicationController
  def index
    @pipeline_jobs = paginate_and_filter_jobs(PipelineJob.all)

    respond_to do |format|
      format.html
      format.js
    end
  end
end
