# frozen_string_literal: true

class JobsController < ApplicationController
  before_action :find_pipeline

  def index
    if @pipeline.harvest.present?
      @harvest_jobs = paginate_and_filter_jobs(@pipeline.harvest&.harvest_jobs)
      @harvest_extraction_jobs = paginate_and_filter_jobs(@pipeline.harvest&.extraction_definition&.extraction_jobs)
    end

    if @pipeline.enrichments.any?
      @enrichment_extraction_jobs = paginate_and_filter_jobs(@pipeline.enrichments&.first&.extraction_definition&.extraction_jobs)
    end
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end
end
