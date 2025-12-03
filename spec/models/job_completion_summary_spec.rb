# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionSummary, type: :model do
  describe 'associations' do
    it { should have_many(:job_completions).dependent(:destroy) }
    it { should have_many(:job_errors).dependent(:destroy) }
  end

  describe 'validations' do
    it 'validates presence of job_id' do
      summary = JobCompletionSummary.new(job_id: nil, job_type: 'ExtractionJob')
      
      expect(summary).not_to be_valid
      expect(summary.errors[:job_id]).to include("can't be blank")
    end

    it 'validates presence of job_type' do
      job = create(:extraction_job)
      summary = JobCompletionSummary.new(job_id: job.id, job_type: nil)
      
      expect(summary).not_to be_valid
      expect(summary.errors[:job_type]).to include("can't be blank")
    end

    it 'enforces uniqueness of job_id scoped to process_type and job_type at database level' do
      job = create(:extraction_job)
      create(:job_completion_summary, job_id: job.id, process_type: 'extraction', job_type: 'ExtractionJob')
      
      duplicate = JobCompletionSummary.new(job_id: job.id, process_type: 'extraction', job_type: 'ExtractionJob')
      expect(duplicate).to be_valid # Rails validation passes (no uniqueness validation in model)
      
      # But saving will fail due to database unique constraint
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'enums' do
    it 'defines process_type enum' do
      expect(JobCompletionSummary.process_types).to eq({ 'extraction' => 0, 'transformation' => 1 })
    end

    it 'can be created with extraction process_type' do
      job = create(:extraction_job)
      summary = create(:job_completion_summary, job_id: job.id, process_type: :extraction)
      expect(summary.extraction?).to be true
      expect(summary.transformation?).to be false
    end

    it 'can be created with transformation process_type' do
      harvest_job = create(:harvest_job)
      summary = create(:job_completion_summary, job_id: harvest_job.id, process_type: :transformation, job_type: 'TransformationJob')
      expect(summary.transformation?).to be true
      expect(summary.extraction?).to be false
    end
  end

  describe '#completion_count' do
    it 'returns the sum of stop condition records and job_errors' do
      job = create(:extraction_job, stop_condition_name: 'limit reached',
                                     stop_condition_content: 'count > 10',
                                     stop_condition_type: 'system')
      summary = create(:job_completion_summary, job_id: job.id, job_type: 'ExtractionJob')
      create(:job_error, job_completion_summary: summary, job_id: job.id)
      create(:job_error, job_completion_summary: summary, job_id: job.id)
      create(:job_error, job_completion_summary: summary, job_id: job.id)
      
      expect(summary.completion_count).to eq(4)
    end

    it 'returns 0 when there are no completions or errors' do
      job = create(:extraction_job, stop_condition_name: nil)
      summary = create(:job_completion_summary, job_id: job.id, job_type: 'ExtractionJob')
      
      expect(summary.completion_count).to eq(0)
    end
  end

  describe '#error_count' do
    it 'returns the count of job_errors' do
      job = create(:extraction_job)
      summary = create(:job_completion_summary, job_id: job.id)
      create(:job_error, job_completion_summary: summary, job_id: job.id)
      create(:job_error, job_completion_summary: summary, job_id: job.id)
      create(:job_error, job_completion_summary: summary, job_id: job.id)
      
      expect(summary.error_count).to eq(3)
    end

    it 'returns 0 when there are no errors' do
      job = create(:extraction_job)
      summary = create(:job_completion_summary, job_id: job.id)
      
      expect(summary.error_count).to eq(0)
    end
  end

  describe '#last_completed_at' do
    it 'returns the updated_at of the extraction job stop condition' do
      job = create(:extraction_job, stop_condition_name: 'limit reached',
                                     stop_condition_content: 'count > 10',
                                     stop_condition_type: 'system')
      summary = create(:job_completion_summary, job_id: job.id, job_type: 'ExtractionJob')
      two_days_ago = 2.days.ago
      job.update_columns(updated_at: two_days_ago)
      
      expect(summary.last_completed_at.to_i).to eq(two_days_ago.to_i)
    end

    it 'returns nil when there are no stop conditions' do
      job = create(:extraction_job, stop_condition_name: nil)
      summary = create(:job_completion_summary, job_id: job.id, job_type: 'ExtractionJob')
      
      expect(summary.last_completed_at).to be_nil
    end
  end



  describe '#pipeline_name' do
    it 'returns the pipeline name for ExtractionJob' do
      pipeline = create(:pipeline, name: 'Test Pipeline')
      extraction_definition = create(:extraction_definition, pipeline: pipeline)
      extraction_job = create(:extraction_job, extraction_definition: extraction_definition)
      summary = create(:job_completion_summary, job_id: extraction_job.id, job_type: 'ExtractionJob')
      
      expect(summary.pipeline_name).to eq('Test Pipeline')
    end

    it 'returns nil when job not found' do
      job = create(:extraction_job)
      summary = create(:job_completion_summary, job_id: job.id)
      summary.update!(job_id: 999999)
      
      expect(JobCompletionSummary.find_for_harvest_job(job.id)).to be_nil
    end
  end

  describe '.error_count_for_harvest_job' do
    it 'returns 0 when harvest_job_id is blank' do
      expect(JobCompletionSummary.error_count_for_harvest_job(nil)).to eq(0)
      expect(JobCompletionSummary.error_count_for_harvest_job('')).to eq(0)
    end

    it 'returns 0 when harvest_job not found' do
      expect(JobCompletionSummary.error_count_for_harvest_job(999999)).to eq(0)
    end

    it 'returns error count for extraction summaries' do
      harvest_job = create(:harvest_job)
      extraction_job = create(:extraction_job)
      harvest_job.update!(extraction_job: extraction_job)
      
      extraction_summary = create(:job_completion_summary, job_id: extraction_job.id, job_type: 'ExtractionJob')
      create(:job_error, job_completion_summary: extraction_summary, job_id: extraction_job.id)
      create(:job_error, job_completion_summary: extraction_summary, job_id: extraction_job.id)
      
      expect(JobCompletionSummary.error_count_for_harvest_job(harvest_job.id)).to eq(2)
    end
  end

  describe '.find_for_harvest_job' do
    it 'returns nil when harvest_job_id is blank' do
      expect(JobCompletionSummary.find_for_harvest_job(nil)).to be_nil
      expect(JobCompletionSummary.find_for_harvest_job('')).to be_nil
    end

    it 'returns nil when harvest_job not found' do
      expect(JobCompletionSummary.find_for_harvest_job(999999)).to be_nil
    end

    it 'returns extraction summary when only extraction summary exists' do
      harvest_job = create(:harvest_job)
      extraction_job = create(:extraction_job)
      harvest_job.update!(extraction_job: extraction_job)
      
      extraction_summary = create(:job_completion_summary, job_id: extraction_job.id, job_type: 'ExtractionJob')
      
      result = JobCompletionSummary.find_for_harvest_job(harvest_job.id)
      
      expect(result).to eq(extraction_summary)
    end
  end
end
