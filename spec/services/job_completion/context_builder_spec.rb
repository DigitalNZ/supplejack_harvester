# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionServices::ContextBuilder do
  let(:harvest_definition) do
    create(:harvest_definition, source_id: 'test_source', name: 'Test Source')
  end
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:job) { create(:extraction_job) }
  let(:error) { StandardError.new('Test error') }

  describe '.create_job_completion' do
    context 'with error' do
      it 'creates a new job completion and summary' do
        expect {
          described_class.create_job_completion(
            origin: 'TestWorker',
            error: error,
            definition: extraction_definition,
            job: job,
            details: { origin: 'TestWorker' }
          )
        }.to change(JobCompletionSummary, :count).by(1)
          .and change(JobCompletion, :count).by(1)

        summary = JobCompletionSummary.last
        expect(summary.source_id).to eq('test_source')
        expect(summary.source_name).to eq('Test Source')
        expect(summary.process_type).to eq('extraction')
        expect(summary.job_type).to eq('ExtractionJob')
        expect(summary.completion_count).to eq(1)

        completion = JobCompletion.last
        expect(completion.source_id).to eq('test_source')
        expect(completion.source_name).to eq('Test Source')
        expect(completion.process_type).to eq('extraction')
        expect(completion.job_type).to eq('ExtractionJob')
        expect(completion.origin).to eq('TestWorker')
        expect(completion.message).to include('Test error')
        expect(completion.details['exception_class']).to eq('StandardError')
        expect(completion.details['exception_message']).to eq('Test error')
        expect(completion.details['origin']).to eq('TestWorker')
        expect(completion.details['job_id']).to eq(job.id)
        expect(completion.details['job_class']).to eq(job.class.name)
      end

      it 'creates job completion with stack trace' do
        error_with_backtrace = StandardError.new('Test error')
        error_with_backtrace.set_backtrace(['/app/test.rb:1:in `test_method'])

        described_class.create_job_completion(
          origin: 'TestWorker',
          error: error_with_backtrace,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        completion = JobCompletion.last
        expect(completion.stack_trace).to eq(['/app/test.rb:1:in `test_method'])
        expect(completion.details['stack_trace']).to eq(['/app/test.rb:1:in `test_method'])
      end

      it 'handles error without backtrace' do
        error_no_backtrace = StandardError.new('Test error')

        described_class.create_job_completion(
          origin: 'TestWorker',
          error: error_no_backtrace,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        completion = JobCompletion.last
        expect(completion.stack_trace).to eq([])
      end
    end

    context 'with stop condition' do
      it 'creates stop condition completion' do
        expect {
          described_class.create_job_completion(
            origin: 'TestWorker',
            error: nil,
            definition: extraction_definition,
            job: job,
            details: {
              stop_condition_name: 'test_condition',
              stop_condition_content: 'if count > 100',
              stop_condition_type: 'user'
            }
          )
        }.to change(JobCompletionSummary, :count).by(1)
          .and change(JobCompletion, :count).by(1)

        summary = JobCompletionSummary.last

        completion = JobCompletion.last
        expect(completion.details['stop_condition_name']).to eq('test_condition')
        expect(completion.details['stop_condition_content']).to eq('if count > 100')
        expect(completion.details['stop_condition_type']).to eq('user')
      end
    end

    context 'with duplicate job completion' do
      it 'increments summary count instead of creating duplicate completion' do
        # Create first completion
        described_class.create_job_completion(
          origin: 'TestWorker',
          error: error,
          definition: extraction_definition,
          job: job,
          details: { origin: 'TestWorker' }
        )

        summary = JobCompletionSummary.last
        initial_count = summary.completion_count
        initial_completion_count = JobCompletion.count

        # Try to create duplicate (same source, process, job, origin, and message prefix)
        described_class.create_job_completion(
          origin: 'TestWorker',
          error: error,
          definition: extraction_definition,
          job: job,
          details: { origin: 'TestWorker' }
        )

        expect(JobCompletion.count).to eq(initial_completion_count)
        expect(summary.reload.completion_count).to eq(initial_count + 1)
      end

      it 'creates new completion when message prefix differs' do
        error1 = StandardError.new('Error one')
        error2 = StandardError.new('Error two')

        described_class.create_job_completion(
          origin: 'TestWorker',
          error: error1,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        expect {
          described_class.create_job_completion(
            origin: 'TestWorker',
            error: error2,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.to change(JobCompletion, :count).by(1)
      end

      it 'creates new completion when origin differs' do
        described_class.create_job_completion(
          origin: 'Worker1',
          error: error,
          definition: extraction_definition,
          job: job,
          details: {}
        )

        expect {
          described_class.create_job_completion(
            origin: 'Worker2',
            error: error,
            definition: extraction_definition,
            job: job,
            details: {}
          )
        }.to change(JobCompletion, :count).by(1)
      end
    end

    context 'with transformation definition' do
      let(:transformation_definition) { harvest_definition.transformation_definition }

      it 'creates completion with transformation process type' do
        described_class.create_job_completion(
          origin: 'TestWorker',
          error: error,
          definition: transformation_definition,
          job: job,
          details: {}
        )

        summary = JobCompletionSummary.last
        expect(summary.process_type).to eq('transformation')
        expect(summary.job_type).to eq('TransformationJob')

        completion = JobCompletion.last
        expect(completion.process_type).to eq('transformation')
        expect(completion.job_type).to eq('TransformationJob')
      end
    end

    context 'error handling' do
      it 'raises error when creation fails' do
        allow(JobCompletion).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(JobCompletion.new))

        expect {
          described_class.create_job_completion(
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
