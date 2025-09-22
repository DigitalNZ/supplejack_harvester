# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionSummary do
  describe 'validations' do
    subject { build(:job_completion_summary) }

    it { is_expected.to validate_presence_of(:extraction_id) }
    it { is_expected.to validate_uniqueness_of(:extraction_id).case_insensitive }
    it { is_expected.to validate_presence_of(:extraction_name) }
    it { is_expected.to validate_presence_of(:error_type) }
    it { is_expected.to validate_presence_of(:error_details) }
    it { is_expected.to validate_presence_of(:error_count) }
    it { is_expected.to validate_numericality_of(:error_count).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:old_summary) { create(:job_completion_summary, last_error_at: 1.day.ago) }
    let!(:error_summary) { create(:job_completion_summary, error_type: 'error', last_error_at: 2.hours.ago) }
    let!(:stop_condition_summary) { create(:job_completion_summary, :stop_condition, last_error_at: 3.hours.ago) }
    let!(:summary_with_errors) { create(:job_completion_summary, error_count: 5, last_error_at: 4.hours.ago) }
    let!(:summary_no_errors) { create(:job_completion_summary, :no_errors, last_error_at: 5.hours.ago) }

    describe '.by_error_type' do
      it 'filters by error type' do
        expect(described_class.by_error_type('error')).to include(error_summary)
        expect(described_class.by_error_type('error')).not_to include(stop_condition_summary)
        expect(described_class.by_error_type('stop condition')).to include(stop_condition_summary)
        expect(described_class.by_error_type('stop condition')).not_to include(error_summary)
      end
    end
  end

  describe 'class methods' do
    describe '.group_by_error_type' do
      let!(:error_summary1) { create(:job_completion_summary, error_type: 'error') }
      let!(:error_summary2) { create(:job_completion_summary, error_type: 'error') }
      let!(:stop_condition_summary) { create(:job_completion_summary, :stop_condition) }

      it 'groups summaries by error type and counts them' do
        result = described_class.group_by_error_type
        expect(result['error']).to eq(2)
        expect(result['stop condition']).to eq(1)
      end
    end

    describe '.total_errors' do
      let!(:summary1) { create(:job_completion_summary, error_count: 3) }
      let!(:summary2) { create(:job_completion_summary, error_count: 2) }
      let!(:summary3) { create(:job_completion_summary, :no_errors) }

      it 'sums all error counts' do
        expect(described_class.total_errors).to eq(5)
      end
    end

    describe '.log_error' do
      let(:extraction_id) { SecureRandom.uuid }
      let(:extraction_name) { 'Test Extraction' }
      let(:message) { 'Test error message' }
      let(:details) do
        {
          worker_class: 'TestWorker',
          job_id: 'job_123',
          harvest_job_id: 'harvest_456',
          pipeline_job_id: 'pipeline_789',
          harvest_report_id: 'report_101',
          stack_trace: 'Error: test error',
          context: { test: true }
        }
      end

      context 'when creating a new error summary' do
        it 'creates a new JobCompletionSummary with error details' do
          expect {
            described_class.log_error(
              extraction_id: extraction_id,
              extraction_name: extraction_name,
              message: message,
              details: details
            )
          }.to change(described_class, :count).by(1)

          summary = described_class.last
          expect(summary.extraction_id).to eq(extraction_id)
          expect(summary.extraction_name).to eq(extraction_name)
          expect(summary.error_type).to eq('error')
          expect(summary.error_count).to eq(1)
          expect(summary.first_error_at).to be_present
          expect(summary.last_error_at).to be_present
        end

        it 'stores error details correctly' do
          summary = described_class.log_error(
            extraction_id: extraction_id,
            extraction_name: extraction_name,
            message: message,
            details: details
          )

          error_entry = summary.error_details.first
          expect(error_entry['message']).to eq(message)
          expect(error_entry['details']).to eq(details.deep_stringify_keys)
          expect(error_entry['timestamp']).to be_present
          expect(error_entry['worker_class']).to eq('TestWorker')
          expect(error_entry['job_id']).to eq('job_123')
          expect(error_entry['harvest_job_id']).to eq('harvest_456')
          expect(error_entry['pipeline_job_id']).to eq('pipeline_789')
          expect(error_entry['harvest_report_id']).to eq('report_101')
          expect(error_entry['stack_trace']).to eq('Error: test error')
          expect(error_entry['context']).to eq({ "test" => true })
        end
      end

      context 'when updating an existing error summary' do
        let!(:existing_summary) do
          create(:job_completion_summary, extraction_id: extraction_id, error_count: 1)
        end

        it 'adds to existing error details' do
          expect {
            described_class.log_error(
              extraction_id: extraction_id,
              extraction_name: extraction_name,
              message: message,
              details: details
            )
          }.not_to change(described_class, :count)

          existing_summary.reload
          expect(existing_summary.error_count).to eq(2)
          expect(existing_summary.error_details.size).to eq(2)
          expect(existing_summary.last_error_at).to be > existing_summary.first_error_at
        end

        it 'preserves first_error_at timestamp' do
          original_first_error = existing_summary.first_error_at
          
          described_class.log_error(
            extraction_id: extraction_id,
            extraction_name: extraction_name,
            message: message,
            details: details
          )

          existing_summary.reload
          expect(existing_summary.first_error_at).to eq(original_first_error)
        end
      end
    end

    describe '.log_stop_condition_hit' do
      let(:extraction_id) { SecureRandom.uuid }
      let(:extraction_name) { 'Test Extraction' }
      let(:stop_condition_name) { 'max_records' }
      let(:stop_condition_content) { 'if records.count > 100' }
      let(:details) { { additional: 'context' } }

      context 'when creating a new stop condition summary' do
        it 'creates a new JobCompletionSummary with stop condition details' do
          expect {
            described_class.log_stop_condition_hit(
              extraction_id: extraction_id,
              extraction_name: extraction_name,
              stop_condition_name: stop_condition_name,
              stop_condition_content: stop_condition_content,
              details: details
            )
          }.to change(described_class, :count).by(1)

          summary = described_class.last
          expect(summary.extraction_id).to eq(extraction_id)
          expect(summary.extraction_name).to eq(extraction_name)
          expect(summary.error_type).to eq('stop condition')
          expect(summary.error_count).to eq(1)
        end

        it 'stores stop condition details correctly' do
          summary = described_class.log_stop_condition_hit(
            extraction_id: extraction_id,
            extraction_name: extraction_name,
            stop_condition_name: stop_condition_name,
            stop_condition_content: stop_condition_content,
            details: details
          )

          error_entry = summary.error_details.first
          expect(error_entry['message']).to eq("Stop condition '#{stop_condition_name}' was triggered")
          expect(error_entry['details']['stop_condition_name']).to eq(stop_condition_name)
          expect(error_entry['details']['stop_condition_content']).to eq(stop_condition_content)
          expect(error_entry['details']['is_system_condition']).to be false
          expect(error_entry['details']['additional']).to eq('context')
          expect(error_entry['timestamp']).to be_present
        end

        it 'stores system stop condition details correctly' do
          system_details = details.merge(condition_type: 'set_number_reached')
          
          summary = described_class.log_stop_condition_hit(
            extraction_id: extraction_id,
            extraction_name: extraction_name,
            stop_condition_name: 'set_number_reached',
            stop_condition_content: 'Set number limit reached',
            details: system_details
          )

          error_entry = summary.error_details.first
          expect(error_entry['message']).to eq("System stop condition 'set_number_reached' was triggered")
          expect(error_entry['details']['stop_condition_name']).to eq('set_number_reached')
          expect(error_entry['details']['stop_condition_content']).to eq('Set number limit reached')
          expect(error_entry['details']['is_system_condition']).to be true
          expect(error_entry['details']['condition_type']).to eq('set_number_reached')
          expect(error_entry['timestamp']).to be_present
        end
      end

      context 'when updating an existing stop condition summary' do
        let!(:existing_summary) do
          create(:job_completion_summary, extraction_id: extraction_id, error_type: 'stop condition', error_count: 1)
        end

        it 'adds to existing error details' do
          expect {
            described_class.log_stop_condition_hit(
              extraction_id: extraction_id,
              extraction_name: extraction_name,
              stop_condition_name: stop_condition_name,
              stop_condition_content: stop_condition_content,
              details: details
            )
          }.not_to change(described_class, :count)

          existing_summary.reload
          expect(existing_summary.error_count).to eq(2)
          expect(existing_summary.error_details.size).to eq(2)
        end
      end
    end
  end

  describe '#stop_condition?' do
    context 'when error_type is "stop condition"' do
      let(:summary) { build(:job_completion_summary, :stop_condition) }

      it 'returns true' do
        expect(summary.stop_condition?).to be true
      end
    end

    context 'when error_type is not "stop condition"' do
      let(:summary) { build(:job_completion_summary, error_type: 'error') }

      it 'returns false' do
        expect(summary.stop_condition?).to be false
      end
    end
  end
end
