# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionSummary, type: :model do
  describe 'validations' do
    it 'validates presence of required fields' do
      summary = build(:job_completion_summary, source_id: nil, source_name: nil, job_type: nil)
      
      expect(summary).not_to be_valid
      expect(summary.errors[:source_id]).to include("can't be blank")
      expect(summary.errors[:source_name]).to include("can't be blank")
      expect(summary.errors[:job_type]).to include("can't be blank")
    end

    it 'validates completion_count is present and non-negative' do
      summary = build(:job_completion_summary, completion_count: nil)
      expect(summary).not_to be_valid
      expect(summary.errors[:completion_count]).to include("can't be blank")

      summary = build(:job_completion_summary, completion_count: -1)
      expect(summary).not_to be_valid
      expect(summary.errors[:completion_count]).to include("must be greater than or equal to 0")
    end

    it 'validates uniqueness of source_id scoped to process_type and job_type' do
      create(:job_completion_summary, source_id: 'test_id', process_type: 'extraction', job_type: 'ExtractionJob')
      
      duplicate = build(:job_completion_summary, source_id: 'test_id', process_type: 'extraction', job_type: 'ExtractionJob')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_id]).to include("has already been taken")
    end
  end

  describe 'enums' do
    it 'defines completion_type enum' do
      expect(JobCompletionSummary.completion_types).to eq({ 'error' => 0, 'stop_condition' => 1 })
    end

    it 'defines process_type enum' do
      expect(JobCompletionSummary.process_types).to eq({ 'extraction' => 0, 'transformation' => 1 })
    end

    it 'can be created with error completion_type' do
      summary = create(:job_completion_summary, completion_type: :error)
      expect(summary.error?).to be true
      expect(summary.stop_condition?).to be false
    end

    it 'can be created with stop_condition completion_type' do
      summary = create(:job_completion_summary, :stop_condition)
      expect(summary.stop_condition?).to be true
      expect(summary.error?).to be false
    end

    it 'can be created with extraction process_type' do
      summary = create(:job_completion_summary, process_type: :extraction)
      expect(summary.extraction?).to be true
      expect(summary.transformation?).to be false
    end

    it 'can be created with transformation process_type' do
      summary = create(:job_completion_summary, :transformation)
      expect(summary.transformation?).to be true
      expect(summary.extraction?).to be false
    end
  end

  describe 'scopes' do
    it 'has by_completion_type scope' do
      error_summary = create(:job_completion_summary, completion_type: :error)
      stop_condition_summary = create(:job_completion_summary, completion_type: :stop_condition)
      
      error_results = JobCompletionSummary.by_completion_type(:error)
      expect(error_results).to include(error_summary)
      expect(error_results).not_to include(stop_condition_summary)
    end
  end

  describe 'defaults' do
    it 'sets default values for new records' do
      summary = JobCompletionSummary.new
      
      expect(summary.completion_count).to eq(0)
    end
  end

  describe 'instance methods' do
    let(:pipeline) { create(:pipeline, name: 'Test Pipeline') }
    let(:harvest_definition) { create(:harvest_definition, source_id: 'test_source', pipeline: pipeline) }
    let(:extraction_definition) { create(:extraction_definition, name: 'Test Extraction', pipeline: pipeline) }
    let(:transformation_definition) { create(:transformation_definition, name: 'Test Transformation', pipeline: pipeline) }
    let(:summary) { create(:job_completion_summary, source_id: 'test_source', process_type: :extraction) }

    before do
      harvest_definition.update!(extraction_definition: extraction_definition, transformation_definition: transformation_definition)
    end

    describe '#pipeline_name' do
      it 'returns the pipeline name' do
        expect(summary.pipeline_name).to eq('Test Pipeline')
      end

      it 'returns nil when harvest definition not found' do
        summary.update!(source_id: 'unknown_source')
        expect(summary.pipeline_name).to be_nil
      end
    end

    describe '#definition_name' do
      it 'returns extraction definition name for extraction process type' do
        expect(summary.definition_name).to eq('Test Extraction')
      end

      it 'returns transformation definition name for transformation process type' do
        transformation_summary = create(:job_completion_summary, source_id: 'test_source', process_type: :transformation)
        expect(transformation_summary.definition_name).to eq('Test Transformation')
      end

      it 'returns nil when harvest definition not found' do
        summary.update!(source_id: 'unknown_source')
        expect(summary.definition_name).to be_nil
      end
    end

    describe '#job_completions' do
      it 'returns job completions matching source_id, process_type, and job_type' do
        completion1 = create(:job_completion, 
                            source_id: 'test_source',
                            process_type: :extraction,
                            job_type: 'ExtractionJob',
                            origin: 'Worker1',
                            message_prefix: 'ERROR1')
        completion2 = create(:job_completion,
                            source_id: 'test_source',
                            process_type: :extraction,
                            job_type: 'ExtractionJob',
                            origin: 'Worker2',
                            message_prefix: 'ERROR2')
        create(:job_completion,
               source_id: 'other_source',
               process_type: :extraction,
               job_type: 'ExtractionJob',
               origin: 'Worker3',
               message_prefix: 'ERROR3')
        
        expect(summary.job_completions).to include(completion1, completion2)
        expect(summary.job_completions.count).to eq(2)
      end
    end

    describe '#last_completed_at' do
      it 'returns the updated_at of the most recent job completion' do
        old_completion = create(:job_completion,
                               source_id: 'test_source',
                               process_type: :extraction,
                               job_type: 'ExtractionJob',
                               origin: 'Worker1',
                               message_prefix: 'ERROR1',
                               updated_at: 2.days.ago)
        recent_completion = create(:job_completion,
                                  source_id: 'test_source',
                                  process_type: :extraction,
                                  job_type: 'ExtractionJob',
                                  origin: 'Worker2',
                                  message_prefix: 'ERROR2',
                                  updated_at: 1.day.ago)
        
        expect(summary.last_completed_at).to eq(recent_completion.updated_at)
      end

      it 'returns nil when there are no job completions' do
        expect(summary.last_completed_at).to be_nil
      end
    end

    describe '#increment_completion_count' do
      it 'increments the completion count by 1' do
        summary = create(:job_completion_summary, completion_count: 5)
        
        summary.increment_completion_count
        
        expect(summary.reload.completion_count).to eq(6)
      end
    end
  end
end
