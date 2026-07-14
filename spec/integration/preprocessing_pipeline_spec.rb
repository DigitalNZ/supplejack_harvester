# frozen_string_literal: true

require 'rails_helper'

# End-to-end proof that a three-block pre-processing chain runs the whole
# PipelineWorker -> HarvestWorker -> ExtractionWorker -> TransformationWorker
# -> [feed-forward | LoadWorker] flow with Sidekiq running inline.
#
#   position 0 (preprocess): seed an index page, gather 2 category links
#   position 1 (preprocess): fetch each category, gather 2 record links each (4)
#   position 2 (harvest):    fetch each of the 4 record pages and load them
#
# The HTTP for every hop is stubbed with WebMock; the destination API push is
# stubbed too so LoadWorker can complete.
RSpec.describe 'Pre-processing pipeline (3 blocks)', type: :integration do
  let!(:destination) { create(:destination) }
  let!(:pipeline)    { create(:pipeline, name: 'preprocessing-chain') }

  # --- Block 0: seed extraction of the index page -------------------------
  let!(:ed0) do
    create(:extraction_definition, pipeline:, name: 'index-source', format: 'JSON',
                                   base_url: 'https://data.example.com/index', page: 1, paginated: false)
  end
  let!(:request0) { create(:request, extraction_definition: ed0) }
  let!(:td0) do
    create(:transformation_definition, pipeline:, name: 'index-transformation', record_selector: '$.categories[*]')
  end
  let!(:field0) do
    create(:field, name: 'slug', block: "JsonPath.new('slug').on(record).first", transformation_definition: td0)
  end
  let!(:block0) do
    create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'test',
                                extraction_definition: ed0, transformation_definition: td0)
  end

  # --- Block 1: fetch each category, gather its record links --------------
  let!(:ed1) do
    create(:extraction_definition, :enrichment, pipeline:, destination:, name: 'category-source',
                                                base_url: 'https://data.example.com/category')
  end
  let!(:request1) { create(:request, extraction_definition: ed1) }
  let!(:param1) do
    create(:parameter, kind: 'slug', content_type: 'dynamic',
                       content: "response['transformed_record']['slug']", request: request1)
  end
  let!(:td1) do
    create(:transformation_definition, pipeline:, name: 'category-transformation', record_selector: '$.records[*]')
  end
  let!(:field1) do
    create(:field, name: 'ref', block: "JsonPath.new('ref').on(record).first", transformation_definition: td1)
  end
  let!(:block1) do
    create(:harvest_definition, pipeline:, kind: :preprocess, position: 1, source_id: 'test',
                                extraction_definition: ed1, transformation_definition: td1)
  end

  # --- Block 2: fetch each record page and load it ------------------------
  let!(:ed2) do
    create(:extraction_definition, :enrichment, pipeline:, destination:, name: 'record-source',
                                                base_url: 'https://data.example.com/record')
  end
  let!(:request2) { create(:request, extraction_definition: ed2) }
  let!(:param2) do
    create(:parameter, kind: 'slug', content_type: 'dynamic',
                       content: "response['transformed_record']['ref']", request: request2)
  end
  let!(:td2) do
    create(:transformation_definition, pipeline:, name: 'record-transformation', record_selector: '$.items[*]')
  end
  let!(:field2) do
    create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition: td2)
  end
  let!(:block2) do
    create(:harvest_definition, pipeline:, kind: :harvest, position: 2, source_id: 'test',
                                extraction_definition: ed2, transformation_definition: td2)
  end

  let!(:pipeline_job) do
    create(:pipeline_job, pipeline:, destination:,
                          harvest_definitions_to_run: [block0.id, block1.id, block2.id])
  end

  def json_response(body)
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  before do
    # Block 0: the index page lists two categories.
    stub_request(:get, 'https://data.example.com/index')
      .to_return(json_response(categories: [{ slug: 'history' }, { slug: 'science' }]))

    # Block 1: each category page lists two record refs.
    stub_request(:get, 'https://data.example.com/category/history')
      .to_return(json_response(records: [{ ref: 'h1' }, { ref: 'h2' }]))
    stub_request(:get, 'https://data.example.com/category/science')
      .to_return(json_response(records: [{ ref: 's1' }, { ref: 's2' }]))

    # Block 2: each record page carries a title.
    %w[h1 h2 s1 s2].each do |ref|
      stub_request(:get, "https://data.example.com/record/#{ref}")
        .to_return(json_response(items: [{ title: "Title #{ref}" }]))
    end

    # Destination API: harvesting notifications + the record load push.
    stub_request(:get, %r{http://www\.localhost:3000/harvester/sources})
      .to_return(status: 200, body: [{ _id: 1 }].to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:put, %r{http://www\.localhost:3000/harvester/sources/\d+})
      .to_return(status: 200, body: '', headers: {})
    stub_request(:post, 'http://www.localhost:3000/harvester/records/create_batch')
      .to_return(status: 200, body: '', headers: {})
  end

  after do
    # Removes this job's whole preprocess tree (…/preprocess/<pipeline_job_id>),
    # covering every block position's feed-forward folder in one sweep.
    FileUtils.rm_rf(File.dirname(PreProcess::Output.folder(pipeline_job.id, 0)))
  end

  def records_in(folder)
    Dir.glob("#{folder}/**/*.json").sort.flat_map do |path|
      JSON.parse(Extraction::Document.load_from_file(path).body)['records']
    end
  end

  # The chain hands work forward by enqueuing the next worker, and a block only
  # advances once its extraction has fully completed (extraction_completed! is
  # set in ExtractionWorker#job_end, *after* the per-page TransformationWorkers
  # are enqueued). Pure Sidekiq::Testing.inline! would run each TransformationWorker
  # nested inside the still-running ExtractionWorker, before that flag is set, and
  # the preprocess advance would never fire. Draining a fixed worker set to
  # quiescence reproduces the real async ordering (each worker finishes before the
  # jobs it enqueued are run) which is what production relies on.
  CHAIN_WORKERS = [PipelineWorker, HarvestWorker, ExtractionWorker,
                   TransformationWorker, LoadWorker, DeleteWorker].freeze

  def drain_chain
    loop do
      pending = CHAIN_WORKERS.select { |worker| worker.jobs.any? }
      break if pending.empty?

      pending.each(&:drain)
    end
  end

  it 'harvests records discovered across two preprocess hops' do
    Sidekiq::Testing.fake! do
      PipelineWorker.perform_async(pipeline_job.id)
      drain_chain
    end

    # Block 0 feed-forward: the two category records.
    block0_records = records_in(PreProcess::Output.folder(pipeline_job.id, 0))
    expect(block0_records.map { |r| r['transformed_record']['slug'] }).to contain_exactly('history', 'science')

    # Block 1 feed-forward: the four record links (2 per category).
    block1_records = records_in(PreProcess::Output.folder(pipeline_job.id, 1))
    expect(block1_records.map { |r| r['transformed_record']['ref'] }).to contain_exactly('h1', 'h2', 's1', 's2')

    # Block 2 harvest: four record loads were queued and pushed to the API.
    block2_report = pipeline_job.harvest_reports.find_by(definition_name: block2.name)
    expect(block2_report.load_workers_queued).to eq(4)
    expect(block2_report.records_loaded).to eq(4)
  end
end
