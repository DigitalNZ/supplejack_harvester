# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::PreProcessRecordIterator do
  let(:pipeline_job_id) { 99 }
  let(:position)        { 0 }
  let(:folder)          { PreProcess::Output.folder(pipeline_job_id, position) }
  let(:output)          { PreProcess::Output.new(pipeline_job_id, position) }

  after { FileUtils.rm_rf(folder) }

  def yielded_pages
    yielded = []
    described_class.new(folder).each do |document, page|
      yielded << [page, JSON.parse(document.body)['records'].map { |r| r['url'] }]
    end
    yielded
  end

  describe '#each' do
    context 'when the stored page numbers are dense' do
      before do
        output.write([{ 'url' => '/a' }, { 'url' => '/b' }])
        output.write([{ 'url' => '/c' }])
      end

      it 'yields each stored document with its page number in order' do
        expect(yielded_pages).to eq([[1, ['/a', '/b']], [2, ['/c']]])
      end
    end

    context 'when the stored page numbers are sparse' do
      before do
        # TransformationWorker writes pages derived from its own extraction
        # page number, so preprocess output pages can be sparse (e.g. one
        # record per source page with per_page 100 yields 1, 101, 201).
        output.write_page(201, [{ 'url' => '/c' }])
        output.write_page(1, [{ 'url' => '/a' }])
        output.write_page(101, [{ 'url' => '/b' }])
      end

      it 'yields every stored document in page order with sequential indices' do
        expect(yielded_pages).to eq([[1, ['/a']], [2, ['/b']], [3, ['/c']]])
      end
    end
  end
end
