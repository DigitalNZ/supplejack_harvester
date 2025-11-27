# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestWorker, type: :job do
  let(:destination)            { create(:destination) }
  let!(:pipeline)              { create(:pipeline, :figshare) }
  let!(:harvest_definition)    { pipeline.harvest }
  let!(:harvest_job)           { create(:harvest_job, harvest_definition:, pipeline_job:) }

  let!(:full_job)                      { create(:extraction_job, extraction_definition:) }
  let!(:extraction_definition)         { create(:extraction_definition, :figshare) }
  let!(:request_one)                   { create(:request, :figshare_initial_request, extraction_definition:) }
  let!(:request_two)                   { create(:request, :figshare_main_request, extraction_definition:) }

  let!(:pipeline_job) do
    create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [harvest_definition.id])
  end

  before do
    stub_figshare_harvest_requests(request_one)
    stub_figshare_harvest_requests(request_two)
  end

  describe '#perform' do
    it 'creates a HarvestReport' do
      expect {
        HarvestWorker.new.perform(harvest_job.id)
      }.to change(HarvestReport, :count).by(1)
    end

    context 'when the HarvestJob is for a Harvest not using an existing Extraction' do
      it 'creates an ExtractionJob' do
        expect {
          HarvestWorker.new.perform(harvest_job.id)
        }.to change(ExtractionJob, :count).by(1)
      end

      it 'does not queue any TransformationWorkers' do
        expect(TransformationWorker).to receive(:perform_async).exactly(0).times.and_call_original

        HarvestWorker.new.perform(harvest_job.id)
      end
    end

    context 'when the HarvestJob is for an Enrichment' do
      before do
        harvest_definition.update(kind: 'enrichment')
      end

      it 'creates an ExtractionJob' do
        expect {
          HarvestWorker.new.perform(harvest_job.id)
        }.to change(ExtractionJob, :count).by(1)
      end

      it 'does not queue any TransformationWorkers' do
        expect(TransformationWorker).to receive(:perform_async).exactly(0).times.and_call_original

        HarvestWorker.new.perform(harvest_job.id)
      end
    end

    context 'when the HarvestJob is for a Harvest using an existing Extraction' do
      let(:extraction_execution) { Extraction::Execution.new(full_job, extraction_definition) }
      let!(:pipeline_job)           do
        create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [harvest_definition.id], extraction_job_id: full_job.id)
      end

      before do
        extraction_execution.call
        expect(File.exist?(full_job.extraction_folder)).to be true
      end

      it 'does not create an ExtractionJob' do
        expect {
          HarvestWorker.new.perform(harvest_job.id)
        }.to change(ExtractionJob, :count).by(0)
      end

      it 'queues a number of TransformationWorkers based on the number of pages in the Extracted document' do
        expect(TransformationWorker).to receive(:perform_in).exactly(5).times.and_call_original

        HarvestWorker.new.perform(harvest_job.id)
      end

      context 'when the PipelineJob is for a set number of pages' do
        let!(:pipeline_job)           do
          create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [harvest_definition.id], extraction_job_id: full_job.id, pages: 2, page_type: 'set_number')
        end

        it 'queues a number of TransformationWorkers based on the number specified in the PipelineJob' do
          expect(TransformationWorker).to receive(:perform_in).exactly(2).times.and_call_original

          HarvestWorker.new.perform(harvest_job.id)
        end
      end
    end
  end
end
