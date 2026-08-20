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

  describe '#documents' do
    it 'returns pageable Extraction::Documents for the output folder' do
      output.write_page(1, [{ 'url' => '/a' }])

      documents = output.documents

      expect(documents).to be_a(Extraction::Documents)
      expect(documents.total_pages).to eq(1)
      expect(JSON.parse(documents[1].body)['records']).to eq([{ 'url' => '/a' }])
    end
  end

  describe '.pipeline_job_ids_with_output' do
    let(:other_pipeline_job_id) { 43 }
    let(:other_position)        { 1 }

    after do
      FileUtils.rm_rf(described_class.folder(pipeline_job_id, other_position))
      FileUtils.rm_rf(described_class.folder(other_pipeline_job_id, position))
      FileUtils.rm_rf(described_class.folder(other_pipeline_job_id, other_position))
    end

    it 'returns ids of jobs that have written output for the given position' do
      output.write_page(1, [{ 'url' => '/a' }])
      described_class.new(other_pipeline_job_id, position).write_page(1, [{ 'url' => '/b' }])

      expect(described_class.pipeline_job_ids_with_output(position)).to contain_exactly(
        pipeline_job_id, other_pipeline_job_id
      )
    end

    it 'excludes jobs that only wrote output for a different position' do
      described_class.new(pipeline_job_id, other_position).write_page(1, [{ 'url' => '/a' }])

      expect(described_class.pipeline_job_ids_with_output(position)).to eq([])
    end

    it 'returns [] when nothing exists' do
      expect(described_class.pipeline_job_ids_with_output(position)).to eq([])
    end
  end

  describe '.pipeline_job_ids_on_disk' do
    after { FileUtils.rm_rf("#{described_class::FOLDER}/not-a-job-id") }

    # This is the first code path the cleanup worker hits on an environment
    # where nothing has ever preprocessed.
    it 'returns [] when the preprocess folder does not exist yet' do
      FileUtils.rm_rf(described_class::FOLDER)

      expect(described_class.pipeline_job_ids_on_disk).to eq([])
    end

    it 'ignores directories that are not pipeline job ids' do
      FileUtils.rm_rf(described_class::FOLDER)
      output.write_page(1, [{ 'url' => '/a' }])
      FileUtils.mkdir_p("#{described_class::FOLDER}/not-a-job-id")

      expect(described_class.pipeline_job_ids_on_disk).to eq([pipeline_job_id])
    end
  end
end
