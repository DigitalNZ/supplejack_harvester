# frozen_string_literal: true

class JobCompletionSummariesController < ApplicationController
  def index
    @job_completion_summaries = JobCompletionSummary.order(updated_at: :desc).page(params[:page])

    extraction_id = params[:extraction_id]

    return if extraction_id.blank?

    @job_completion_summaries = @job_completion_summaries.where(job_id: extraction_id)
  end

  def show
    @job_completion_summary = JobCompletionSummary.find(params[:id])
  end
end
