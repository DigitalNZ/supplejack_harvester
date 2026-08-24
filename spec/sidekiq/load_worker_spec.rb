# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadWorker, type: :job do
  let!(:pipeline)              { create(:pipeline, :figshare) }
  let!(:harvest_definition)    { pipeline.harvest }
  let!(:enrichment_definition) { create(:harvest_definition, kind: 'enrichment', pipeline:) }
  let(:destination)            { create(:destination) }
  let(:pipeline_job)           do
    create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [enrichment_definition.id])
  end

  def stub_notice_to_api
    notifier = instance_double('Api::Utils::NotifyHarvesting')
    expect(notifier).to receive(:call)
    expect(Api::Utils::NotifyHarvesting).to receive(:new) { notifier }
  end

  describe '#perform' do
    let(:harvest_job) { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }
    let!(:harvest_report) do
      create(
        :harvest_report,
        harvest_job:,
        pipeline_job:,
        extraction_status: 'completed',
        transformation_status: 'completed',
        delete_status: 'completed',
        load_workers_queued: 1
      )
    end

    let!(:field) do
      create(
        :field,
        name: 'title',
        block: "JsonPath.new('title').on(record).first",
        transformation_definition: enrichment_definition.transformation_definition
      )
    end

    context 'when the harvest has completed' do
      it 'queues scoped enrichments that are ready to be run' do
        expect(HarvestWorker).to receive(:perform_async)
        stub_notice_to_api

        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.to change(HarvestJob, :count).by(1)

        expect(HarvestJob.last.target_job_id).to eq harvest_job.name
      end

      it 'does not queue enrichments if there is already an existing one for that pipeline job' do
        create(
          :harvest_job,
          :completed,
          harvest_definition: enrichment_definition,
          pipeline_job:
        )
        stub_notice_to_api

        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.not_to change(HarvestJob, :count)
      end
    end

    context 'when the harvest is not completed' do
      let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let!(:harvest_report) do
        create(:harvest_report, harvest_job:, pipeline_job:, extraction_status: 'running', transformation_status: 'running',
                                delete_status: 'running', load_workers_queued: 1)
      end

      it 'does not queue enrichments' do
        expect(HarvestWorker).not_to receive(:perform_async)

        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.not_to change(HarvestJob, :count)
      end
    end

    context 'when the harvest job is cancelled' do
      let(:cancelled_pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:cancelled_harvest_job) do
        create(:harvest_job, :cancelled, harvest_definition:, pipeline_job: cancelled_pipeline_job)
      end
      let!(:cancelled_harvest_report) do
        create(:harvest_report, harvest_job: cancelled_harvest_job, pipeline_job:)
      end

      it 'does not process any batches when harvest job is cancelled' do
        expect(Load::Execution).not_to receive(:new)

        described_class.new.perform(cancelled_harvest_job.id, '[{"id": "1"}]')
      end
    end

    context 'when the pipeline job is cancelled' do
      let(:cancelled_pipeline_job) { create(:pipeline_job, :cancelled, pipeline:, destination:) }
      let(:harvest_job_with_cancelled_pipeline) { create(:harvest_job, harvest_definition:, pipeline_job: cancelled_pipeline_job) }
      let!(:cancelled_pipeline_harvest_report) do
        create(:harvest_report, harvest_job: harvest_job_with_cancelled_pipeline, pipeline_job: cancelled_pipeline_job)
      end

      it 'does not process any batches when pipeline job is cancelled' do
        expect(Load::Execution).not_to receive(:new)

        described_class.new.perform(harvest_job_with_cancelled_pipeline.id, '[{"id": "1"}]')
      end
    end

    context 'when the Load Execution raises an exception' do
      let(:records) { "[{\"transformed_record\":{\"internal_identifier\":\"test\"}}]" }
      let(:last_attempt) { described_class::MAX_BATCH_ATTEMPTS }

      before do
        allow_any_instance_of(Load::Execution).to receive(:call).and_raise(StandardError)
      end

      it 'retries the Load Execution' do
        expect(Load::Execution).to receive(:new).exactly(2).times

        described_class.new.perform(harvest_job.id, records)
      end

      # Not the app-wide configuration, which is set for extractions and would hold this
      # worker for fifteen minutes on a batch the requeue is going to pick up anyway.
      it 'retries through the load context rather than the default one' do
        allow(::Retriable).to receive(:with_context).and_call_original

        described_class.new.perform(harvest_job.id, records)

        expect(::Retriable).to have_received(:with_context).with(:load, hash_including(:retry_if, :on_retry))
      end

      it 'does not raise, so the slices after the failed one are still loaded' do
        expect { described_class.new.perform(harvest_job.id, records) }.not_to raise_error
      end

      it 'still increments the number of workers completed' do
        expect(harvest_report.load_workers_queued).to eq 1
        expect(harvest_report.load_workers_completed).to eq 0

        described_class.new.perform(harvest_job.id, records)
        harvest_report.reload

        expect(harvest_report.load_workers_completed).to eq 1
      end

      it 'requeues the batch and tells the report to expect it' do
        expect(described_class).to receive(:perform_in_with_priority).with(
          harvest_job.pipeline_job.job_priority, described_class::RETRY_DELAYS.first,
          harvest_job.id, [{ 'transformed_record' => { 'internal_identifier' => 'test' } }].to_json, nil, 2
        )

        described_class.new.perform(harvest_job.id, records)

        expect(harvest_report.reload.load_workers_queued).to eq 2
      end

      it 'records no error while the batch still has attempts left' do
        expect { described_class.new.perform(harvest_job.id, records) }.not_to change(JobError, :count)
        expect(harvest_report.reload.load_status).not_to eq 'errored'
      end

      # On the last attempt the load reaches its completion instead of being abandoned
      # mid-flight, so the destination is told harvesting has finished - which is the point
      # of not re-raising, and why these three stub the notice.
      it 'gives up on a batch that has run out of attempts rather than requeueing it' do
        stub_notice_to_api
        expect(described_class).not_to receive(:perform_in_with_priority)

        described_class.new.perform(harvest_job.id, records, nil, last_attempt)
      end

      it 'records the error once the batch has run out of attempts' do
        stub_notice_to_api

        expect { described_class.new.perform(harvest_job.id, records, nil, last_attempt) }
          .to change(JobError, :count).by(1)
      end

      it 'marks the load errored so the run does not claim it loaded everything' do
        stub_notice_to_api

        described_class.new.perform(harvest_job.id, records, nil, last_attempt)

        expect(harvest_report.reload.load_status).to eq 'errored'
      end
    end

    # A refusal the destination will repeat is not worth waiting on: Retriable re-raises it
    # at once rather than working through its backoff, and it is not requeued either.
    context 'when the Load Execution raises a permanent error' do
      let(:records) { "[{\"transformed_record\":{\"internal_identifier\":\"test\"}}]" }

      # A verifying double rather than a stub on .new: stubbing .new returns nil, and the
      # NoMethodError from calling nil is not the error under test - it is transient, so it
      # would be retried and the example would prove the opposite of what it claims.
      let(:execution) { instance_double(Load::Execution) }

      before do
        allow(execution).to receive(:call).and_raise(Load::PermanentError)
        allow(Load::Execution).to receive(:new).and_return(execution)
        stub_notice_to_api
      end

      it 'does not retry the Load Execution' do
        described_class.new.perform(harvest_job.id, records)

        expect(Load::Execution).to have_received(:new).once
      end

      it 'does not requeue the batch even on the first attempt' do
        expect(described_class).not_to receive(:perform_in_with_priority)

        described_class.new.perform(harvest_job.id, records)
      end

      it 'records the error and marks the load errored straight away' do
        expect { described_class.new.perform(harvest_job.id, records) }.to change(JobError, :count).by(1)

        expect(harvest_report.reload.load_status).to eq 'errored'
      end
    end

    context "when the Api::Utils::NotifyHarvesting raises an exception" do
      before do
        allow_any_instance_of(Api::Utils::NotifyHarvesting).to receive(:call).and_raise(StandardError)
      end

      it "retries the Api::Utils::NotifyHarvesting" do
        expect(Api::Utils::NotifyHarvesting).to receive(:new).exactly(2).times
        described_class.new.perform(harvest_job.id, "[]")
      end

      it "still enqueues enrichment jobs" do
        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.to change(HarvestJob, :count).by(1)

        expect(HarvestJob.last.target_job_id).to eq harvest_job.name
      end
    end
  end
end
