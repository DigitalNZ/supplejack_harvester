# frozen_string_literal: true

module Pipelines
  class TagsController < ApplicationController
    before_action :set_pipeline

    # The editor submits the whole set of tags a pipeline should end up with, so this
    # replaces them rather than adding to them: a tag taken off a pipeline arrives as
    # an absence, and the names that are new arrive as names no tag has yet.
    def update
      tags = Tag.from_names(tag_names)
      unsaveable = tags.reject(&:persisted?)

      if unsaveable.any?
        redirect_to pipeline_path(@pipeline), alert: t('.failure', errors: error_messages(unsaveable))
      elsif @pipeline.update(tags:)
        redirect_to pipeline_path(@pipeline), notice: t('.success')
      else
        redirect_to pipeline_path(@pipeline), alert: t('.failure', errors: error_messages([@pipeline]))
      end
    end

    private

    def tag_names
      params.permit(tag_names: [])[:tag_names]
    end

    def error_messages(records)
      records.flat_map { |record| record.errors.full_messages }.uniq.to_sentence
    end

    def set_pipeline
      @pipeline = Pipeline.find(params[:pipeline_id])
    end
  end
end
