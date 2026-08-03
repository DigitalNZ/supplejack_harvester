# frozen_string_literal: true

require 'rails_helper'

# The point of the Run modal's per-block inputs: a second run harvests from the
# pre-processed data a previous run prepared, instead of pre-processing again.
#
#   position 0 (preprocess): scrape an index page for category slugs
#   position 1 (harvest):    fetch each category page and load its records
#
# Run one does both. Run two runs only the harvest block, pointed at run one's
# pre-processed output, and must never touch the index page again.
RSpec.describe 'Reusing pre-processed data from an earlier run', type: :integration do
  let!(:destination) { create(:destination) }
  let!(:pipeline)    { create(:pipeline, name: 'reuse-preprocessed') }

  # --- Block 0: the pre-processing block ----------------------------------
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

  # --- Block 1: the harvest block that consumes block 0's output ----------
  let!(:ed1) do
    create(:extraction_definition, pipeline:, destination:, name: 'category-source',
                                   base_url: 'https://data.example.com/category')
  end
  let!(:request1) { create(:request, extraction_definition: ed1) }
  let!(:subsequent_request1) { create(:request, extraction_definition: ed1) }
  let!(:param1) do
    create(:parameter, kind: 'slug', content_type: 'dynamic',
                       content: "response['transformed_record']['slug']", request: request1)
  end
  let!(:td1) do
    create(:transformation_definition, pipeline:, name: 'category-transformation', record_selector: '$.items[*]')
  end
  let!(:field1) do
    create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition: td1)
  end
  let!(:block1) do
    create(:harvest_definition, pipeline:, kind: :harvest, position: 1, source_id: 'test',
                                extraction_definition: ed1, transformation_definition: td1)
  end

  let(:first_run) do
    create(:pipeline_job, pipeline:, destination:,
                          block_settings: {
                            block0.id.to_s => { 'run' => true, 'input' => 'fresh' },
                            block1.id.to_s => { 'run' => true, 'input' => 'fresh' }
                          })
  end

  let(:reusing_run) do
    create(:pipeline_job, pipeline:, destination:,
                          block_settings: {
                            block0.id.to_s => { 'run' => false, 'input' => 'fresh' },
                            block1.id.to_s => { 'run' => true, 'input' => "preprocess_output:#{first_run.id}" }
                          })
  end

  def json_response(body)
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  before do
    stub_request(:get, 'https://data.example.com/index')
      .to_return(json_response(categories: [{ slug: 'history' }, { slug: 'science' }]))

    stub_request(:get, 'https://data.example.com/category/history')
      .to_return(json_response(items: [{ title: 'History' }]))
    stub_request(:get, 'https://data.example.com/category/science')
      .to_return(json_response(items: [{ title: 'Science' }]))

    stub_request(:get, %r{http://www\.localhost:3000/harvester/sources})
      .to_return(status: 200, body: [{ _id: 1 }].to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:put, %r{http://www\.localhost:3000/harvester/sources/\d+})
      .to_return(status: 200, body: '', headers: {})
    stub_request(:post, 'http://www.localhost:3000/harvester/records/create_batch')
      .to_return(status: 200, body: '', headers: {})
  end

  after do
    [first_run, reusing_run].each do |job|
      FileUtils.rm_rf(File.dirname(PreProcess::Output.folder(job.id, 0)))
    end
  end

  # See the comment on CHAIN_WORKERS in spec/integration/preprocessing_pipeline_spec.rb
  # for why this drains rather than running Sidekiq inline.
  CHAIN_WORKERS = [PipelineWorker, HarvestWorker, ExtractionWorker,
                   TransformationWorker, LoadWorker, DeleteWorker].freeze

  def run(pipeline_job)
    Sidekiq::Testing.fake! do
      PipelineWorker.perform_async(pipeline_job.id)

      loop do
        pending = CHAIN_WORKERS.select { |worker| worker.jobs.any? }
        break if pending.empty?

        pending.each(&:drain)
      end
    end
  end

  def records_loaded(pipeline_job)
    pipeline_job.harvest_reports.find_by(definition_name: block1.name).records_loaded
  end

  it 'harvests from the earlier run without pre-processing again' do
    run(first_run)

    expect(records_loaded(first_run)).to eq 2
    expect(a_request(:get, 'https://data.example.com/index')).to have_been_made.once

    run(reusing_run)

    # The harvest ran again over the same two categories...
    expect(records_loaded(reusing_run)).to eq 2
    expect(a_request(:get, 'https://data.example.com/category/history')).to have_been_made.twice

    # ...but the pre-processing block did not run: the index page was fetched once
    # in total, and this run wrote no pre-processed output of its own.
    expect(a_request(:get, 'https://data.example.com/index')).to have_been_made.once
    expect(reusing_run.harvest_jobs.map(&:harvest_definition)).to eq [block1]
    expect(Dir.glob("#{PreProcess::Output.folder(reusing_run.id, 0)}/**/*.json")).to be_empty
  end
end
