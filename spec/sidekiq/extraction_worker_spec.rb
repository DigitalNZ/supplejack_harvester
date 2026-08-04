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
        create(:extraction_definition, kind: 'enrichment', destination:, source_id: 'test')
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

    context 'when the extraction is for a block that iterates the previous block (position > 0)' do
      let(:destination) { create(:destination) }
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:preprocess_definition) { create(:harvest_definition, pipeline:, kind: :preprocess, position: 1) }
      let(:harvest_job) { create(:harvest_job, harvest_definition: preprocess_definition, pipeline_job:) }
      let(:extraction_definition) { create(:extraction_definition, destination:) }
      let!(:request) { create(:request, extraction_definition:) }
      let(:extraction_job) do
        create(:extraction_job, extraction_definition:, harvest_job:, status: 'queued')
      end

      it 'triggers the Enrichment Extraction process instead of the Harvest Extraction process' do
        expect_any_instance_of(Extraction::EnrichmentExecution).to receive(:call)
        subject.perform(extraction_job.id)
      end

      it 'does not trigger the Harvest Extraction process' do
        expect_any_instance_of(Extraction::Execution).not_to receive(:call)
        subject.perform(extraction_job.id)
      end
    end

    it 'marks the job as completed' do
      subject.perform(extraction_job.id)
      extraction_job.reload
      expect(extraction_job.completed?).to be true
    end

    context 'when the extraction is for a preprocess block' do
      let(:pipeline_job) do
        create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [enrichment_definition.id])
      end
      let(:preprocess_definition) { create(:harvest_definition, pipeline:, kind: :preprocess, position: 0) }
      let(:harvest_job) { create(:harvest_job, harvest_definition: preprocess_definition, pipeline_job:) }
      let(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:) }
      let!(:enrichment_definition) { create(:harvest_definition, kind: 'enrichment', pipeline:) }
      let!(:enrichment_field) do
        create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                       transformation_definition: enrichment_definition.transformation_definition)
      end

      it 'does not enqueue an enrichment job when the preprocess block completes, ' \
         'because the harvest has not run yet' do
        expect do
          subject.perform(extraction_job.id, harvest_report.id)
        end.not_to change(HarvestJob.where(harvest_definition: enrichment_definition), :count)
      end
    end

    context 'when the extraction is part of a harvest' do
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:) }

      context 'when the extraction definition has split enabled' do
        let!(:enrichment_definition) { create(:harvest_definition, kind: 'enrichment', pipeline:) }
        let!(:enrichment_field) do
          create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                         transformation_definition: enrichment_definition.transformation_definition)
        end
        let(:pipeline_job) do
          create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [enrichment_definition.id])
        end

        before do
          extraction_definition.update(split: true, split_selector: '//record')
        end

        it 'queues a split worker to process the extracted documents' do
          expect do
            subject.perform(extraction_job.id, harvest_report.id)
          end.to change(SplitWorker.jobs, :size).by(1)
        end

        it 'does not mark the extraction as completed, as the split worker completes it after splitting' do
          subject.perform(extraction_job.id, harvest_report.id)
          harvest_report.reload
          expect(harvest_report.extraction_completed?).to be false
        end

        it 'does not queue enrichments, as no records have been transformed or loaded yet' do
          expect do
            subject.perform(extraction_job.id, harvest_report.id)
          end.not_to change(HarvestJob.where(harvest_definition: enrichment_definition), :count)
        end
      end

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
