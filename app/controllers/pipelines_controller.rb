# frozen_string_literal: true

class PipelinesController < ApplicationController
  include LastEditedBy

  before_action :find_pipeline, only: %w[destroy clone harvest_definitions]
  before_action :assign_show_pipeline, only: %w[show update]
  before_action :assign_show_variables, only: %w[show update]
  before_action :assign_destinations, only: %w[show update]

  def index
    @pipeline = Pipeline.new
    status = params['status']

    @pipelines = if status == 'queued'
                   PipelineJob.where.missing(:harvest_reports).map(&:pipeline).uniq
                 elsif status == 'running'
                   HarvestReport.running.map { |report| report.pipeline_job.pipeline }
                                .uniq
                 else
                   pipelines
                 end
  end

  def show; end

  def create
    @pipeline = Pipeline.new(pipeline_params)

    if @pipeline.save
      redirect_to pipeline_path(@pipeline), notice: t('.success')
    else
      flash.alert = t('.failure')
      @pipelines = pipelines
      render :index
    end
  end

  def update
    if @pipeline.update(pipeline_params)
      redirect_to pipeline_path(@pipeline)
    else
      flash.alert = t('.failure')
      render :show
    end
  end

  def destroy
    if @pipeline.destroy
      redirect_to pipelines_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to pipeline_path(@pipeline)
    end
  end

  def clone
    cloned_pipeline = Pipeline.new(pipeline_params)

    if cloned_pipeline.save

      @pipeline.harvest_definitions.each do |harvest_definition|
        harvest_definition.clone(cloned_pipeline).save!
      end

      redirect_to pipeline_path(cloned_pipeline), notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to pipeline_path(@pipeline)
    end
  end

  def harvest_definitions
    @harvest_definitions = @pipeline.harvest_definitions
    render json: @harvest_definitions.map(&:to_h)
  end

  private

  def assign_show_pipeline
    @pipeline = Pipeline.includes(
      :schedules,
      harvest_definitions: [
        { extraction_definition: :last_edited_by },
        { transformation_definition: %i[fields last_edited_by] }
      ]
    ).find(params[:id])
  end

  def assign_destinations
    @destinations = Destination.all
  end

  def assign_show_variables
    @harvest_definition = @pipeline.harvest_definitions.find(&:harvest?) || HarvestDefinition.new(pipeline: @pipeline)
    @extraction_jobs = @harvest_definition.extraction_definition&.extraction_jobs&.order(created_at: :desc)
    @enrichment_definition = HarvestDefinition.new(pipeline: @pipeline)
  end

  def find_pipeline
    @pipeline = Pipeline.find(params[:id])
  end

  def pipelines
    PipelineSearchQuery.new(params).call.order(sort_by).page(params[:page])
  end

  def sort_by
    @sort_by ||= params['sort_by'] == 'name' ? { name: :asc } : { updated_at: :desc }
  end

  def pipeline_params
    safe_params = params.require(:pipeline).permit(:name, :description)
    merge_last_edited_by(safe_params)
  end
end
