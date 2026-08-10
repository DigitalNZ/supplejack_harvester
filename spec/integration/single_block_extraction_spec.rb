# frozen_string_literal: true

require 'rails_helper'

# Running one block's extraction on its own, from the block's dropdown rather than a
# pipeline run. A block after the first in the chain has no records of its own to start
# from, so it is given an earlier run's pre-processed output - the same records the
# request preview shows.
#
# Before this, such a job took the seed path: its dynamic parameters evaluated against
# no previous response, Parameter#dynamic_evaluation swallowed the failure into an
# "-evaluation-error" slug, and the extraction fetched a meaningless URL.
RSpec.describe 'Extracting a single block from stored records', type: :integration do
  let!(:destination) { create(:destination) }
  let!(:pipeline)    { create(:pipeline, name: 'single-block') }

  let!(:extraction_definition) do
    create(:extraction_definition, pipeline:, destination:, name: 'category-source',
                                   base_url: 'https://data.example.com/category')
  end
  let!(:request_one)        { create(:request, extraction_definition:) }
  let!(:subsequent_request) { create(:request, extraction_definition:) }
  let!(:parameter) do
    create(:parameter, kind: 'slug', content_type: 'dynamic',
                       content: "response['transformed_record']['slug']", request: request_one)
  end
  let!(:block) do
    create(:harvest_definition, pipeline:, kind: :preprocess, position: 1, source_id: 'second',
                                extraction_definition:, transformation_definition: nil)
  end

  # The run whose output this extraction works from.
  let!(:source_run) { create(:pipeline_job, pipeline:, destination:) }

  def record(slug)
    { 'transformed_record' => { 'slug' => slug } }
  end

  def stored_output(page, *slugs)
    PreProcess::Output.new(source_run.id, 0).write_page(page, slugs.map { |slug| record(slug) })
  end

  def extraction_job(kind:)
    create(:extraction_job, extraction_definition:, kind:,
                            source_pipeline_job_id: source_run.id, source_position: 0)
  end

  before do
    %w[history science art].each do |slug|
      stub_request(:get, "https://data.example.com/category/#{slug}")
        .to_return(status: 200, body: { records: [{ ref: slug }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end
  end

  after do
    FileUtils.rm_rf(File.dirname(PreProcess::Output.folder(source_run.id, 0)))
    ExtractionJob.find_each { |job| FileUtils.rm_rf(job.extraction_folder) }
  end

  it 'extracts one request per stored record instead of an unevaluated URL' do
    stored_output(1, 'history', 'science')

    ExtractionWorker.new.perform(extraction_job(kind: 'full').id)

    expect(a_request(:get, 'https://data.example.com/category/history')).to have_been_made.once
    expect(a_request(:get, 'https://data.example.com/category/science')).to have_been_made.once

    # The symptom of the old behaviour: a slug built from a failed evaluation.
    expect(a_request(:get, %r{/category/response-transformed_record-slug-evaluation-error}))
      .not_to have_been_made
  end

  it 'takes only the first stored page for a sample' do
    stored_output(1, 'history', 'science')
    stored_output(2, 'art')

    ExtractionWorker.new.perform(extraction_job(kind: 'sample').id)

    expect(a_request(:get, 'https://data.example.com/category/history')).to have_been_made.once
    expect(a_request(:get, 'https://data.example.com/category/science')).to have_been_made.once
    expect(a_request(:get, 'https://data.example.com/category/art')).not_to have_been_made
  end

  # The first block of a chain has no records to be given: it seeds itself, and must
  # keep doing so.
  it 'leaves a first block seeding its own extraction' do
    first_definition = create(:extraction_definition, pipeline:, destination:, name: 'index-source',
                                                     base_url: 'https://data.example.com/index',
                                                     paginated: false)
    create(:request, extraction_definition: first_definition)
    create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'first',
                                extraction_definition: first_definition, transformation_definition: nil)
    stub_request(:get, 'https://data.example.com/index')
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    job = create(:extraction_job, extraction_definition: first_definition, kind: 'full')
    ExtractionWorker.new.perform(job.id)

    expect(a_request(:get, 'https://data.example.com/index')).to have_been_made
    expect(job.reload).not_to be_iterates_preprocess_output
  end
end
