# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionServices::ContextBuilder do
  let(:harvest_definition) do
    create(:harvest_definition, source_id: 'test_source', name: 'Test Source')
  end
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:job) { create(:extraction_job) }
  let(:error) { StandardError.new('Test error') }

  describe '.create_job_completion_or_error' do
    context 'with error' do
      it 'creates a new job error and summary' do
        expect {
          described_class.create_job_completion_or_error(
            origin: 'TestWorker',
            error: error,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.to change(JobCompletionSummary, :count).by(1)
          .and change(JobError, :count).by(1)

        summary = JobCompletionSummary.last
        expect(summary.job_id).to eq(job.id)
        expect(summary.process_type).to eq('extraction')
        expect(summary.job_type).to eq('ExtractionJob')
        expect(summary.completion_count).to eq(1)

        job_error = JobError.last
        expect(job_error.job_id).to eq(job.id)
        expect(job_error.process_type).to eq('extraction')
        expect(job_error.job_type).to eq('ExtractionJob')
        expect(job_error.origin).to eq('TestWorker')
        expect(job_error.message).to eq('StandardError: Test error')
        expect(job_error.stack_trace).to eq([])
      end

      it 'creates job error with stack trace' do
        error_with_backtrace = StandardError.new('Test error')
        error_with_backtrace.set_backtrace(['/app/test.rb:1:in `test_method`'])

        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error_with_backtrace,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        job_error = JobError.last
        expect(job_error.stack_trace).to eq(['/app/test.rb:1:in `test_method`'])
      end

      it 'handles error without backtrace' do
        error_no_backtrace = StandardError.new('Test error')

        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error_no_backtrace,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        job_error = JobError.last
        expect(job_error.stack_trace).to eq([])
      end
    end

    context 'with stop condition' do
      it 'creates stop condition completion' do
        expect {
          described_class.create_job_completion_or_error(
            origin: 'TestWorker',
            error: nil,
            definition: extraction_definition,
            job: job,
            stop_condition_name: 'test_condition',
            stop_condition_content: 'if count > 100',
            stop_condition_type: 'user'
          )
        }.to change(JobCompletionSummary, :count).by(1)
          .and change(JobCompletion, :count).by(1)

        summary = JobCompletionSummary.last
        expect(summary.job_id).to eq(job.id)
        expect(summary.process_type).to eq('extraction')
        expect(summary.job_type).to eq('ExtractionJob')

        completion = JobCompletion.last
        expect(completion.job_id).to eq(job.id)
        expect(completion.process_type).to eq('extraction')
        expect(completion.completion_type).to eq('stop_condition')
        expect(completion.origin).to eq('TestWorker')
        expect(completion.stop_condition_name).to eq('test_condition')
        expect(completion.stop_condition_content).to eq('if count > 100')
        expect(completion.stop_condition_type).to eq('user')
      end
    end

    context 'with duplicate job error' do
      it 'does not create duplicate error when same error exists' do
        # Create first error
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        summary = JobCompletionSummary.last
        initial_count = summary.completion_count
        initial_error_count = JobError.count

        # Try to create duplicate (same job_id, origin, and message)
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        expect(JobError.count).to eq(initial_error_count)
        expect(summary.reload.completion_count).to eq(initial_count)
      end

      it 'creates new error when message differs' do
        error1 = StandardError.new('Error one')
        error2 = StandardError.new('Error two')

        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error1,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        expect {
          described_class.create_job_completion_or_error(
            origin: 'TestWorker',
            error: error2,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.to change(JobError, :count).by(1)
      end

      it 'creates new error when origin differs' do
        described_class.create_job_completion_or_error(
          origin: 'Worker1',
          error: error,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        expect {
          described_class.create_job_completion_or_error(
            origin: 'Worker2',
            error: error,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.to change(JobError, :count).by(1)
      end

      it 'handles duplicate check with truncated messages (255 chars)' do
        long_message = 'A' * 300
        error_long = StandardError.new(long_message)

        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error_long,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        initial_error_count = JobError.count

        # Try to create duplicate with same first 255 chars
        error_long2 = StandardError.new(long_message)
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error_long2,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        expect(JobError.count).to eq(initial_error_count)
      end
    end

    context 'with duplicate job completion' do
      it 'does not create duplicate completion when same stop condition exists' do
        # Create first completion
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: nil,
          definition: extraction_definition,
          job: job,
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user'
        )

        summary = JobCompletionSummary.last
        initial_count = summary.completion_count
        initial_completion_count = JobCompletion.count

        # Try to create duplicate (same job_id, origin, and stop_condition_name)
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: nil,
          definition: extraction_definition,
          job: job,
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user'
        )

        expect(JobCompletion.count).to eq(initial_completion_count)
        expect(summary.reload.completion_count).to eq(initial_count)
      end

      it 'creates new completion when stop condition name differs' do
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: nil,
          definition: extraction_definition,
          job: job,
          stop_condition_name: 'condition1',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user'
        )

        expect {
          described_class.create_job_completion_or_error(
            origin: 'TestWorker',
            error: nil,
            definition: extraction_definition,
            job: job,
            stop_condition_name: 'condition2',
            stop_condition_content: 'if count > 100',
            stop_condition_type: 'user'
          )
        }.to change(JobCompletion, :count).by(1)
      end
    end

    context 'with transformation definition' do
      let(:transformation_definition) { harvest_definition.transformation_definition }

      it 'creates error with transformation process type' do
        described_class.create_job_completion_or_error(
          origin: 'TestWorker',
          error: error,
          definition: transformation_definition,
          job: job,
          details: {}
        )

        summary = JobCompletionSummary.last
        expect(summary.process_type).to eq('transformation')
        expect(summary.job_type).to eq('TransformationJob')

        job_error = JobError.last
        expect(job_error.process_type).to eq('transformation')
        expect(job_error.job_type).to eq('TransformationJob')
      end
    end

    context 'error handling' do
      it 'handles race condition when duplicate check passes but insert fails' do
        allow(JobError).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique.new('Duplicate entry', JobError.new))

        expect {
          described_class.create_job_completion_or_error(
            origin: 'TestWorker',
            error: error,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.not_to raise_error
      end

      it 'raises error when creation fails with other errors' do
        allow(JobError).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(JobError.new))

        expect {
          described_class.create_job_completion_or_error(
            origin: 'TestWorker',
            error: error,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
