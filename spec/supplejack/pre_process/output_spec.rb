# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreProcess::Output do
  let(:pipeline_job_id) { 42 }
  let(:position)        { 0 }
  subject(:output)      { described_class.new(pipeline_job_id, position) }

  after { FileUtils.rm_rf(described_class.folder(pipeline_job_id, position)) }

  describe '#write' do
    it 'writes records as a {records:[…]} document readable by Extraction::Documents' do
      output.write([{ 'url' => '/a' }, { 'url' => '/b' }])

      documents = Extraction::Documents.new(described_class.folder(pipeline_job_id, position))
      body = JSON.parse(documents[1].body)

      expect(documents.total_pages).to eq(1)
      expect(body['records']).to eq([{ 'url' => '/a' }, { 'url' => '/b' }])
    end

    it 'appends a new page on each call' do
      output.write([{ 'url' => '/a' }])
      output.write([{ 'url' => '/b' }])

      documents = Extraction::Documents.new(described_class.folder(pipeline_job_id, position))
      expect(documents.total_pages).to eq(2)
      expect(JSON.parse(documents[2].body)['records']).to eq([{ 'url' => '/b' }])
    end
  end

  describe '#write_page' do
    # Concurrency safety: TransformationWorker jobs run in parallel, each
    # holding a distinct extraction page number. Safety comes from the file
    # path being a pure function of the given page — no shared disk-count
    # read like #write's next_page — so distinct pages can never collide.
    it 'writes to a path derived purely from the given page number' do
      output.write_page(5, [{ 'url' => '/e' }])
      output.write_page(3, [{ 'url' => '/c' }])

      folder = described_class.folder(pipeline_job_id, position)
      expect(Dir.glob("#{folder}/**/*.json").sort).to eq(
        ["#{folder}/1/preprocess__000000003.json", "#{folder}/1/preprocess__000000005.json"]
      )

      documents = Extraction::Documents.new(folder)
      expect(JSON.parse(documents[5].body)['records']).to eq([{ 'url' => '/e' }])
    end
  end
end
