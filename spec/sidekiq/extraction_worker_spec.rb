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

    # Transformation workers run while the extraction is still going, and decline to
    # finish the report until the extraction completes. If the last of them finishes in
    # the window between this worker reading the report and marking the extraction
    # completed, both sides used to stand aside and the block sat on "running" with every
    # worker accounted for.
    context 'when the transformation workers finish while the extraction is still running' do
      let(:destination)   { create(:destination) }
      let(:pipeline_job)  { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)   { create(:harvest_job, harvest_definition: pipeline.harvest, pipeline_job:) }
      let(:extraction_job) do
        create(:extraction_job, extraction_definition:, harvest_job:, status: 'queued')
      end
      let!(:harvest_report) do
        create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'running',
                                transformation_workers_queued: 1, transformation_workers_completed: 0)
      end

      before do
        allow_any_instance_of(Extraction::Execution).to receive(:call)

        # Drops the last transformation worker's increment into the window that used to
        # lose it: after this worker has read the report, before it decides whether the
        # transformation is finished.
        allow_any_instance_of(HarvestReport).to receive(:extraction_completed!).and_wrap_original do |original, *args|
          HarvestReport.where(id: harvest_report.id)
                       .update_all('transformation_workers_completed = transformation_workers_queued')
          original.call(*args)
        end
      end

      it 'finishes the report rather than leaving the transformation running' do
        subject.perform(extraction_job.id, harvest_report.id)

        harvest_report.reload

        expect(harvest_report.extraction_status).to eq 'completed'
        expect(harvest_report.transformation_status).to eq 'completed'
        expect(harvest_report.load_status).to eq 'completed'
      end

      # Finishing the report is not enough: a pre-processing block exists to feed the next
      # one, and the transformation workers that stood aside are also the ones that would
      # normally step the chain forward.
      context 'and the block is a pre-processing one with a block after it' do
        let(:preprocess_block) { create(:harvest_definition, pipeline:, kind: :preprocess, position: 0) }
        let!(:next_block)      { create(:harvest_definition, pipeline:, kind: :preprocess, position: 1) }
        let(:harvest_job)      { create(:harvest_job, harvest_definition: preprocess_block, pipeline_job:) }
        let(:pipeline_job) do
          create(:pipeline_job, pipeline:, destination:,
                                harvest_definitions_to_run: [preprocess_block.id.to_s, next_block.id.to_s])
        end

        it 'starts the next block' do
          allow(HarvestWorker).to receive(:perform_async_with_priority)

          expect { subject.perform(extraction_job.id, harvest_report.id) }
            .to change { pipeline_job.harvest_jobs.where(harvest_definition: next_block).count }.by(1)

          expect(HarvestWorker).to have_received(:perform_async_with_priority)
        end
      end
    end

    # On a long harvest the loads keep up with the pages, so the whole block can be done
    # bar the paperwork by the time the extraction ends: this worker marks all four
    # statuses itself, which makes it the last thing to touch the run and the only thing
    # left to end it. The run used to sit on "Running" with its block showing Completed -
    # which is what the jobs page reads, so the two pages disagreed.
    context 'when the transformation and load workers all finish while the extraction is still running' do
      let(:destination) { create(:destination) }
      let(:harvest)     { pipeline.harvest }
      let(:pipeline_job) do
        create(:pipeline_job, pipeline:, destination:, status: 'running', start_time: Time.zone.now,
                              harvest_definitions_to_run: [harvest.id.to_s])
      end
      let(:harvest_job) { create(:harvest_job, harvest_definition: harvest, pipeline_job:) }
      let(:extraction_job) do
        create(:extraction_job, extraction_definition:, harvest_job:, status: 'queued')
      end
      let!(:harvest_report) do
        create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'running',
                                transformation_workers_queued: 1, transformation_workers_completed: 1,
                                load_workers_queued: 1, load_workers_completed: 1)
      end

      before do
        allow_any_instance_of(Extraction::Execution).to receive(:call)
        stub_notify_harvesting(destination, false)
      end

      it 'completes the block' do
        subject.perform(extraction_job.id, harvest_report.id)

        expect(harvest_report.reload.status).to eq 'completed'
      end

      it 'ends the run rather than leaving it running with its block completed' do
        subject.perform(extraction_job.id, harvest_report.id)

        expect(pipeline_job.reload).to be_completed
      end

      # The destination was told this source was being harvested when the first load was
      # queued, and it leaves the source's records alone until it is told otherwise. Only
      # the load workers used to say so, and here they all stood aside.
      it 'tells the destination the source is no longer being harvested' do
        subject.perform(extraction_job.id, harvest_report.id)

        expect(a_request(:put, %r{#{Regexp.escape(destination.url)}/harvester/sources/\d+})
          .with(body: { source: { harvesting: false } }.to_json)).to have_been_made
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
