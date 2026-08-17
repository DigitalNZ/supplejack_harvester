# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RunCompletion do
  let(:destination) { create(:destination) }
  let(:pipeline)    { create(:pipeline) }
  let!(:first_block)  { create(:harvest_definition, :preprocess, pipeline:, position: 0) }
  let!(:second_block) { create(:harvest_definition, pipeline:, position: 1) }

  let(:pipeline_job) do
    create(:pipeline_job, pipeline:, destination:,
                          harvest_definitions_to_run: [first_block.id.to_s, second_block.id.to_s])
  end

  def report_for(definition, statuses = {})
    harvest_job = create(:harvest_job, harvest_definition: definition, pipeline_job:)

    create(:harvest_report, pipeline_job:, harvest_job:, kind: definition.kind,
                            **{ extraction_status: 'completed', transformation_status: 'completed',
                                load_status: 'completed', delete_status: 'completed' }.merge(statuses))
  end

  it 'is unfinished while a block is still working' do
    report_for(first_block, transformation_status: 'running')

    expect(described_class.new(pipeline_job)).not_to be_finished
  end

  # The gap between one block finishing and the next one starting: every report there is
  # has finished, but the run is not over.
  it 'is unfinished when a later block has not started yet' do
    report_for(first_block)

    expect(described_class.new(pipeline_job)).not_to be_finished
  end

  it 'is finished once every block of the run has finished' do
    report_for(first_block)
    report_for(second_block)

    expect(described_class.new(pipeline_job)).to be_finished
  end

  it 'is finished when the run stopped early and its blocks are done' do
    job = create(:pipeline_job, pipeline:, destination:,
                                harvest_definitions_to_run: [first_block.id.to_s])
    harvest_job = create(:harvest_job, harvest_definition: first_block, pipeline_job: job)
    create(:harvest_report, pipeline_job: job, harvest_job:, kind: 'preprocess',
                            extraction_status: 'completed', transformation_status: 'completed',
                            load_status: 'completed', delete_status: 'completed')

    expect(described_class.new(job)).to be_finished
  end

  it 'is unfinished before anything has started' do
    expect(described_class.new(pipeline_job)).not_to be_finished
  end

  it 'reports a run whose block errored' do
    report_for(first_block)
    report_for(second_block, load_status: 'errored')

    completion = described_class.new(pipeline_job)

    expect(completion).to be_finished
    expect(completion).to be_errored
  end

  # Enrichments are queued off the back of a completed harvest, so a run that has one
  # ticked is not over until it has been queued and finished.
  context 'with an enrichment still to queue' do
    let!(:enrichment) do
      definition = create(:harvest_definition, :enrichment, pipeline:)
      create(:field, transformation_definition: definition.transformation_definition)
      definition
    end
    let(:pipeline_job) do
      create(:pipeline_job, pipeline:, destination:,
                            harvest_definitions_to_run: [first_block.id.to_s, second_block.id.to_s,
                                                         enrichment.id.to_s])
    end

    it 'is unfinished until the enrichment has run' do
      report_for(first_block)
      report_for(second_block, kind: 'harvest')

      expect(described_class.new(pipeline_job)).not_to be_finished
    end
  end
end
