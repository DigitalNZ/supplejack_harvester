# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion, type: :model do
  describe 'associations' do
    it { should belong_to(:job_completion_summary) }
  end

  describe 'validations' do
    it 'validates presence of job_id' do
      completion = JobCompletion.new(job_id: nil, origin: 'TestWorker', stop_condition_type: 'user', stop_condition_name: 'test', stop_condition_content: 'content')
      
      expect(completion).not_to be_valid
      expect(completion.errors[:job_id]).to include("can't be blank")
    end

    it 'validates presence of stop_condition_type' do
      job = create(:extraction_job)
      completion = JobCompletion.new(job_id: job.id, origin: 'TestWorker', stop_condition_type: nil, stop_condition_name: 'test', stop_condition_content: 'content')
      
      expect(completion).not_to be_valid
      expect(completion.errors[:stop_condition_type]).to include("can't be blank")
    end

    it 'validates presence of stop_condition_name' do
      job = create(:extraction_job)
      completion = JobCompletion.new(job_id: job.id, origin: 'TestWorker', stop_condition_type: 'user', stop_condition_name: nil, stop_condition_content: 'content')
      
      expect(completion).not_to be_valid
      expect(completion.errors[:stop_condition_name]).to include("can't be blank")
    end

    it 'validates presence of process_type' do
      job = create(:extraction_job)
      completion = JobCompletion.new(job_id: job.id, origin: 'TestWorker', process_type: nil, stop_condition_type: 'user', stop_condition_name: 'test', stop_condition_content: 'content')
      
      expect(completion).not_to be_valid
      expect(completion.errors[:process_type]).to include("can't be blank")
    end

    it 'validates presence of origin' do
      job = create(:extraction_job)
      completion = JobCompletion.new(job_id: job.id, origin: nil, stop_condition_type: 'user', stop_condition_name: 'test', stop_condition_content: 'content')
      
      expect(completion).not_to be_valid
      expect(completion.errors[:origin]).to include("can't be blank")
    end

    it 'enforces uniqueness of job_id scoped to origin and stop_condition_name at database level' do
      summary = create(:job_completion_summary)
      job = create(:extraction_job)
      create(:job_completion,
             job_completion_summary: summary,
             job_id: job.id,
             origin: 'TestWorker',
             stop_condition_name: 'test_condition')
      
      duplicate = JobCompletion.new(
        job_completion_summary: summary,
        job_id: job.id,
        origin: 'TestWorker',
        stop_condition_name: 'test_condition',
        stop_condition_type: 'user',
        stop_condition_content: 'content',
        process_type: :extraction
      )
      
      expect(duplicate).to be_valid # Rails validation passes (no uniqueness validation in model)
      
      # But saving will fail due to database unique constraint
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'enums' do
    it 'defines process_type enum' do
      expect(JobCompletion.process_types).to eq({ 'extraction' => 0, 'transformation' => 1 })
    end

    it 'can be created with extraction process_type' do
      job = create(:extraction_job)
      summary = create(:job_completion_summary, job_id: job.id)
      completion = create(:job_completion, job_completion_summary: summary, job_id: job.id, process_type: :extraction)
      expect(completion.extraction?).to be true
      expect(completion.transformation?).to be false
    end

    it 'can be created with transformation process_type' do
      harvest_job = create(:harvest_job)
      summary = create(:job_completion_summary, job_id: harvest_job.id, process_type: :transformation, job_type: 'TransformationJob')
      completion = create(:job_completion, job_completion_summary: summary, job_id: harvest_job.id, process_type: :transformation)
      expect(completion.transformation?).to be true
      expect(completion.extraction?).to be false
    end
  end

  describe 'scopes' do
    it 'orders by updated_at descending when using order' do
      job = create(:extraction_job)
      summary = create(:job_completion_summary, job_id: job.id)
      old_completion = create(:job_completion, job_completion_summary: summary, job_id: job.id, updated_at: 2.days.ago)
      recent_completion = create(:job_completion, job_completion_summary: summary, job_id: job.id, updated_at: 1.day.ago)
      oldest_completion = create(:job_completion, job_completion_summary: summary, job_id: job.id, updated_at: 3.days.ago)
      
      results = JobCompletion.order(updated_at: :desc)
      expect(results.first).to eq(recent_completion)
      expect(results.second).to eq(old_completion)
      expect(results.third).to eq(oldest_completion)
    end
  end
end
