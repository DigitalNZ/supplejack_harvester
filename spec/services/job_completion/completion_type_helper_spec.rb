# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionServices::CompletionTypeHelper do
  describe '.determine_job_type' do
    let(:params) { { job_type: 'CustomJob' } }
    let(:completion_type) { :error }

    it 'returns job_type from params when present' do
      result = described_class.determine_job_type(params, completion_type)
      expect(result).to eq('CustomJob')
    end

    context 'without job_type in params' do
      let(:params) { {} }

      it 'returns default job type for stop condition' do
        result = described_class.determine_job_type(params, :stop_condition)
        expect(result).to eq('ExtractionJob')
      end

      it 'returns default job type for error' do
        result = described_class.determine_job_type(params, :error)
        expect(result).to eq('Unknown')
      end
    end
  end

  describe '.determine_process_type' do
    let(:params) { { process_type: :transformation } }

    it 'returns process_type from params when present' do
      result = described_class.determine_process_type(params)
      expect(result).to eq(:transformation)
    end

    context 'without process_type in params' do
      let(:params) { {} }

      it 'returns default extraction process type' do
        result = described_class.determine_process_type(params)
        expect(result).to eq(:extraction)
      end
    end
  end

  describe '.default_job_type' do
    it 'returns ExtractionJob for stop condition' do
      result = described_class.default_job_type(:stop_condition)
      expect(result).to eq('ExtractionJob')
    end

    it 'returns Unknown for error' do
      result = described_class.default_job_type(:error)
      expect(result).to eq('Unknown')
    end
  end
end
