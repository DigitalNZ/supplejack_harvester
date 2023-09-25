# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionWorker, type: :job do
  let(:pipeline)              { create(:pipeline, :figshare) }
  let(:destination)           { create(:destination) }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let(:extraction_job)        { create(:extraction_job, extraction_definition:, status: 'queued') }
  let(:subject)               { described_class.new }
  let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }

  describe 'options' do
    it 'sets the retry to 0' do
      expect(subject.sidekiq_options_hash['retry']).to eq 0
    end
  end

  describe '#sidekiq_retries_exhausted' do
    it 'marks the job as errored in sidekiq_retries_exhausted' do
      subject.sidekiq_retries_exhausted_block.call({ 'args' => [extraction_job.id] }, nil)
      extraction_job.reload
      expect(extraction_job.errored?).to be true
    end
  end

  describe '#perform' do
    before { stub_figshare_harvest_requests(request) }

    context 'when the extraction is for an enrichment' do
      let(:destination) { create(:destination) }
      let(:extraction_definition) do
        create(:extraction_definition, kind: 'enrichment', destination:, source_id: 'test',
                                       enrichment_url: 'http://www.google.co.nz')
      end
      let(:enrichment_extraction_job) { create(:extraction_job, extraction_definition:, status: 'queued') }

      it 'triggers the Enrichment Extraction process' do
        expect_any_instance_of(Extraction::EnrichmentExecution).to receive(:call)
        subject.perform(enrichment_extraction_job.id)
      end
    end

    context 'whent the extraction is for a harvest' do
      it 'triggers the Harvest Extraction process' do
        expect_any_instance_of(Extraction::Execution).to receive(:call)
        subject.perform(extraction_job.id)
      end

      it 'does not trigger the Harvest Extraction process' do
        expect_any_instance_of(Extraction::EnrichmentExecution).not_to receive(:call)
        subject.perform(extraction_job.id)
      end
    end

    it 'marks the job as completed' do
      subject.perform(extraction_job.id)
      extraction_job.reload
      expect(extraction_job.completed?).to be true
    end

    context 'when the extraction is part of a harvest' do
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:) }

      context 'when the extraction is completed' do
        it 'updates the harvest report that the extraction is completed' do
          expect(harvest_report.extraction_completed?).to be false
          subject.perform(extraction_job.id, harvest_report.id)
          harvest_report.reload
          expect(harvest_report.extraction_completed?).to be true
        end

        it 'updates the harvest report that the transformation is completed if the transformation workers are completed' do
          expect(harvest_report.transformation_completed?).to be false
          subject.perform(extraction_job.id, harvest_report.id)
          harvest_report.reload
          expect(harvest_report.transformation_completed?).to be true
        end

        it 'updates the harvest report that the load is completed if the load workers are completed' do
          expect(harvest_report.load_completed?).to be false
          subject.perform(extraction_job.id, harvest_report.id)
          harvest_report.reload
          expect(harvest_report.load_completed?).to be true
        end

        it 'updates the harvest report that the delete is completed if the delete workers are completed' do
          expect(harvest_report.delete_completed?).to be false
          subject.perform(extraction_job.id, harvest_report.id)
          harvest_report.reload
          expect(harvest_report.delete_completed?).to be true
        end
      end
    end
  end
end
