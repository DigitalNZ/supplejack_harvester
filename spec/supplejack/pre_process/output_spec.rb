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
    it 'writes to the given page number rather than a disk-derived count' do
      output.write_page(5, [{ 'url' => '/e' }])

      documents = Extraction::Documents.new(described_class.folder(pipeline_job_id, position))
      expect(JSON.parse(documents[5].body)['records']).to eq([{ 'url' => '/e' }])
    end

    it 'does not collide when two writers target distinct pages at the same time' do
      # Simulates two concurrent TransformationWorker jobs, each already
      # knowing its own unique page number, writing at (roughly) the same
      # time. Because the page number is passed in rather than derived from
      # Dir.glob(...).count, neither write can clobber the other.
      barrier = Queue.new
      writer = ->(page) do
        barrier.pop
        output.write_page(page, [{ 'url' => "/#{page}" }])
      end

      threads = [Thread.new { writer.call(1) }, Thread.new { writer.call(2) }]
      2.times { barrier << true }
      threads.each(&:join)

      documents = Extraction::Documents.new(described_class.folder(pipeline_job_id, position))
      expect(documents.total_pages).to eq(2)
      expect(JSON.parse(documents[1].body)['records']).to eq([{ 'url' => '/1' }])
      expect(JSON.parse(documents[2].body)['records']).to eq([{ 'url' => '/2' }])
    end
  end
end
