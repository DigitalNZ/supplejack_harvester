# frozen_string_literal: true

require 'rails_helper'

# A harvest whose extraction finds nothing. The source answers, so there are pages to
# show for it, but no record matches the transformation's selector: nothing to load,
# nothing to delete, and no LoadWorker ever runs.
#
# That is the one route through a run where no load happens, and both of the places
# that move a run forward hang off one - PipelineJob#enqueue_enrichment_jobs is called
# from LoadWorker#job_end as well as from the extraction worker, and only the load
# worker still has the run in hand once the harvest's report is complete. A run whose
# harvest loads nothing therefore has to be carried by the report callbacks alone.
RSpec.describe 'A harvest that extracts no records', type: :integration do
  let!(:destination) { create(:destination) }
  let!(:pipeline)    { create(:pipeline, name: 'zero-record-harvest') }

  # --- The harvest block: the source answers with an empty record set -------
  let!(:harvest_extraction) do
    create(:extraction_definition, pipeline:, destination:, name: 'oai-source',
                                   base_url: 'https://data.example.com/oai', page: 1, paginated: false)
  end
  let!(:harvest_request) { create(:request, extraction_definition: harvest_extraction) }
  let!(:harvest_transformation) do
    create(:transformation_definition, pipeline:, name: 'oai-transformation', record_selector: '$.records[*]')
  end
  let!(:harvest_field) do
    create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                   transformation_definition: harvest_transformation)
  end
  let!(:harvest_block) do
    create(:harvest_definition, pipeline:, kind: :harvest, position: 0, source_id: 'zero_records',
                                extraction_definition: harvest_extraction,
                                transformation_definition: harvest_transformation)
  end

  # --- The enrichment queued off the back of it ----------------------------
  let!(:enrichment_extraction) do
    create(:extraction_definition, :enrichment, pipeline:, destination:, name: 'oai-enrichment')
  end
  let!(:enrichment_request)     { create(:request, extraction_definition: enrichment_extraction) }
  let!(:enrichment_subsequent)  { create(:request, extraction_definition: enrichment_extraction) }
  let!(:enrichment_transformation) do
    create(:transformation_definition, pipeline:, name: 'enrichment-transformation',
                                       record_selector: '$.records[*]')
  end
  let!(:enrichment_field) do
    create(:field, name: 'subject', block: "JsonPath.new('subject').on(record).first",
                   transformation_definition: enrichment_transformation)
  end
  let!(:enrichment_block) do
    create(:harvest_definition, pipeline:, kind: :enrichment, source_id: 'zero_records_enrich',
                                extraction_definition: enrichment_extraction,
                                transformation_definition: enrichment_transformation)
  end

  let!(:pipeline_job) do
    create(:pipeline_job, pipeline:, destination:,
                          harvest_definitions_to_run: [harvest_block.id, enrichment_block.id])
  end

  before do
    # The source answers, but with no records in it.
    stub_request(:get, 'https://data.example.com/oai')
      .to_return(status: 200, body: { records: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    # The destination has nothing for the enrichment to iterate either.
    stub_request(:get, %r{http://www\.localhost:3000/harvester/records})
      .to_return(status: 200, body: { records: [], meta: { total_pages: 1 } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, %r{http://www\.localhost:3000/harvester/sources})
      .to_return(status: 200, body: [{ _id: 1 }].to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:put, %r{http://www\.localhost:3000/harvester/sources/\d+})
      .to_return(status: 200, body: '', headers: {})
  end

  after do
    ExtractionJob.find_each { |job| FileUtils.rm_rf(job.extraction_folder) }
  end

  # See the note in spec/integration/preprocessing_pipeline_spec.rb: draining a fixed
  # worker set to quiescence reproduces the real ordering, where each worker finishes
  # before the jobs it enqueued are run.
  def chain_workers
    [PipelineWorker, HarvestWorker, ExtractionWorker, TransformationWorker, LoadWorker, DeleteWorker]
  end

  def drain_chain
    loop do
      pending = chain_workers.select { |worker| worker.jobs.any? }
      break if pending.empty?

      pending.each(&:drain)
    end
  end

  def run!
    Sidekiq::Testing.fake! do
      PipelineWorker.perform_async(pipeline_job.id)
      drain_chain
    end
  end

  it 'completes the harvest block rather than leaving it running' do
    run!

    report = pipeline_job.harvest_reports.find_by(kind: 'harvest')

    expect(report.records_transformed).to eq 0
    expect(report.load_workers_queued).to eq 0
    expect(report.status).to eq 'completed'
  end

  it 'still queues the enrichment that the run asked for' do
    run!

    expect(pipeline_job.harvest_jobs.where(harvest_definition: enrichment_block)).to exist
  end

  it 'ends the run rather than leaving it on running' do
    run!

    expect(pipeline_job.reload).to be_completed
    expect(pipeline_job.end_time).to be_present
  end
end
