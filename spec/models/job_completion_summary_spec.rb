# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionSummary do
  describe 'validations' do
    subject { build(:job_completion_summary) }

    it { is_expected.to validate_presence_of(:extraction_id) }
    it { is_expected.to validate_uniqueness_of(:extraction_id).case_insensitive }
    it { is_expected.to validate_presence_of(:extraction_name) }
    it { is_expected.to validate_presence_of(:completion_details) }
    it { is_expected.to validate_presence_of(:completion_count) }
    it { is_expected.to validate_numericality_of(:completion_count).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:old_summary) { create(:job_completion_summary, last_occurred_at: 1.day.ago) }
    let!(:error_summary) { create(:job_completion_summary, completion_type: :error, last_occurred_at: 2.hours.ago) }
    let!(:stop_condition_summary) { create(:job_completion_summary, :stop_condition, last_occurred_at: 3.hours.ago) }
    let!(:summary_with_errors) { create(:job_completion_summary, completion_count: 5, last_occurred_at: 4.hours.ago) }
    let!(:summary_no_errors) { create(:job_completion_summary, :no_errors, last_occurred_at: 5.hours.ago) }

    describe '.by_completion_type' do
      it 'filters by completion type' do
        expect(described_class.by_completion_type(:error)).to include(error_summary)
        expect(described_class.by_completion_type(:error)).not_to include(stop_condition_summary)
        expect(described_class.by_completion_type(:stop_condition)).to include(stop_condition_summary)
        expect(described_class.by_completion_type(:stop_condition)).not_to include(error_summary)
      end
    end
  end

  describe '.group_by_completion_type' do
    let!(:error_summary1) { create(:job_completion_summary, completion_type: :error) }
    let!(:error_summary2) { create(:job_completion_summary, completion_type: :error) }
    let!(:stop_condition_summary) { create(:job_completion_summary, :stop_condition) }

    it 'groups summaries by completion type and counts them' do
      result = described_class.group_by_completion_type
      expect(result['error']).to eq(2)
      expect(result['stop_condition']).to eq(1)
    end
  end

  describe '.total_completions' do
    let!(:summary1) { create(:job_completion_summary, completion_count: 3) }
    let!(:summary2) { create(:job_completion_summary, completion_count: 2) }
    let!(:summary3) { create(:job_completion_summary, :no_errors) }

    it 'sums all completion counts' do
      expect(described_class.total_completions).to eq(5)
    end
  end

  describe '.log_completion' do
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

    context 'when creating a new completion summary' do
      it 'creates a new JobCompletionSummary with completion details' do
        expect {
          described_class.log_completion(
            extraction_id: extraction_id,
            extraction_name: extraction_name,
            message: message,
            details: details
          )
        }.to change(described_class, :count).by(1)

        summary = described_class.last
        expect(summary.extraction_id).to eq(extraction_id)
        expect(summary.extraction_name).to eq(extraction_name)
        expect(summary.completion_type).to eq('error')
        expect(summary.completion_count).to eq(1)
        expect(summary.created_at).to be_present
        expect(summary.last_occurred_at).to be_present
      end

      it 'stores completion details correctly' do
        summary = described_class.log_completion(
          extraction_id: extraction_id,
          extraction_name: extraction_name,
          message: message,
          details: details
        )

        completion_entry = summary.completion_details.first
        expect(completion_entry['message']).to eq(message)
        expect(completion_entry['details']).to eq(details.deep_stringify_keys)
        expect(completion_entry['timestamp']).to be_present
        expect(completion_entry['worker_class']).to eq('TestWorker')
        expect(completion_entry['job_id']).to eq('job_123')
        expect(completion_entry['harvest_job_id']).to eq('harvest_456')
        expect(completion_entry['pipeline_job_id']).to eq('pipeline_789')
        expect(completion_entry['harvest_report_id']).to eq('report_101')
        expect(completion_entry['stack_trace']).to eq('Error: test error')
        expect(completion_entry['context']).to eq({ "test" => true })
      end
    end

    context 'when updating an existing completion summary' do
      let!(:existing_summary) do
        create(:job_completion_summary, extraction_id: extraction_id, completion_count: 1)
      end

      it 'adds to existing completion details' do
        expect {
          described_class.log_completion(
            extraction_id: extraction_id,
            extraction_name: extraction_name,
            message: message,
            details: details
          )
        }.not_to change(described_class, :count)

        existing_summary.reload
        expect(existing_summary.completion_count).to eq(2)
        expect(existing_summary.completion_details.size).to eq(2)
        expect(existing_summary.last_occurred_at).to be > existing_summary.created_at
      end

      it 'preserves created_at timestamp' do
        original_created_at = existing_summary.created_at
        
        described_class.log_completion(
          extraction_id: extraction_id,
          extraction_name: extraction_name,
          message: message,
          details: details
        )

        existing_summary.reload
        expect(existing_summary.created_at).to eq(original_created_at)
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
        expect(summary.completion_type).to eq('stop_condition')
        expect(summary.completion_count).to eq(1)
      end

      it 'stores stop condition details correctly' do
        summary = described_class.log_stop_condition_hit(
          extraction_id: extraction_id,
          extraction_name: extraction_name,
          stop_condition_name: stop_condition_name,
          stop_condition_content: stop_condition_content,
          details: details
        )

        completion_entry = summary.completion_details.first
        expect(completion_entry['message']).to eq("Stop condition '#{stop_condition_name}' was triggered")
        expect(completion_entry['details']['stop_condition_name']).to eq(stop_condition_name)
        expect(completion_entry['details']['stop_condition_content']).to eq(stop_condition_content)
        expect(completion_entry['details']['is_system_condition']).to be false
        expect(completion_entry['details']['additional']).to eq('context')
        expect(completion_entry['timestamp']).to be_present
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

        completion_entry = summary.completion_details.first
        expect(completion_entry['message']).to eq("System stop condition 'set_number_reached' was triggered")
        expect(completion_entry['details']['stop_condition_name']).to eq('set_number_reached')
        expect(completion_entry['details']['stop_condition_content']).to eq('Set number limit reached')
        expect(completion_entry['details']['is_system_condition']).to be true
        expect(completion_entry['details']['condition_type']).to eq('set_number_reached')
        expect(completion_entry['timestamp']).to be_present
      end
    end

    context 'when updating an existing stop condition summary' do
      let!(:existing_summary) do
        create(:job_completion_summary, extraction_id: extraction_id, completion_type: 'stop_condition', completion_count: 1)
      end

      it 'adds to existing completion details' do
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
        expect(existing_summary.completion_count).to eq(2)
        expect(existing_summary.completion_details.size).to eq(2)
      end
    end
  end

  describe '#stop_condition?' do
    context 'when completion_type is "stop_condition"' do
      let(:summary) { build(:job_completion_summary, :stop_condition) }

      it 'returns true' do
        expect(summary.stop_condition?).to be true
      end
    end

    context 'when completion_type is not "stop_condition"' do
      let(:summary) { build(:job_completion_summary, completion_type: 'error') }

      it 'returns false' do
        expect(summary.stop_condition?).to be false
      end
    end
  end
end
