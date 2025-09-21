# frozen_string_literal: true

class JobCompletionSummaryController < ApplicationController
  before_action :set_job_completion_summary, only: [:show]

  def index
    @job_completion_summary = JobCompletionSummary.recent_errors.page(params[:page])

    if params[:error_type].present?
      @job_completion_summary = @job_completion_summary.where(error_type: params[:error_type])
    end

    return if params[:extraction_id].blank?

    @job_completion_summary = @job_completion_summary.where(extraction_id: params[:extraction_id])
  end

  def show; end

  private

  def set_job_completion_summary
    @job_completion_summary = JobCompletionSummary.find(params[:id])
  end
end
