# frozen_string_literal: true

module Api
  class PipelineStatusesController < ApplicationController
    before_action :find_pipeline

    def show
      render json: { status: }
    end

    private

    def find_pipeline
      @pipeline = Pipeline.find(params[:id])
    end

    def queued_jobs?
      @pipeline.pipeline_jobs.where.missing(:harvest_reports).present?
    end

    def running_jobs?
      HarvestReport.where(pipeline_job_id: @pipeline.pipeline_jobs.map(&:id)).any? do |job|
        job.status == 'running'
      end
    end

    def status
      return 'queued' if queued_jobs?
      return 'running' if running_jobs?

      'inactive'
    end
    
    private

    def authenticate_api_key
      authenticate_or_request_with_http_token do |token, options|
        User.find_by(api_key: token).admin?
      end
    end
  end
end
