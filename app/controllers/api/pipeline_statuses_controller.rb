# frozen_string_literal: true

module Api
  class PipelineStatusesController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :setup_two_factor_authentication

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
  end
end
