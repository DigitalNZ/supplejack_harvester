# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobError, type: :model do
  describe 'associations' do
    it { should belong_to(:job_completion_summary) }
  end

  describe 'validations' do
    it 'validates presence of job_id' do
      job_error = build(:job_error, job_id: nil)
      
      expect(job_error).not_to be_valid
      expect(job_error.errors[:job_id]).to include("can't be blank")
    end

    it 'validates presence of job_type' do
      job_error = build(:job_error, job_type: nil)
      
      expect(job_error).not_to be_valid
      expect(job_error.errors[:job_type]).to include("can't be blank")
    end

    it 'validates presence of stack_trace' do
      job_error = build(:job_error, stack_trace: nil)
      
      expect(job_error).not_to be_valid
      expect(job_error.errors[:stack_trace]).to include("can't be blank")
    end

    it 'validates presence of message' do
      job_error = build(:job_error, message: nil)
      
      expect(job_error).not_to be_valid
      expect(job_error.errors[:message]).to include("can't be blank")
    end

    it 'validates presence of process_type' do
      job_error = build(:job_error, process_type: nil)
      
      expect(job_error).not_to be_valid
      expect(job_error.errors[:process_type]).to include("can't be blank")
    end

    it 'validates presence of origin' do
      job_error = build(:job_error, origin: nil)
      
      expect(job_error).not_to be_valid
      expect(job_error.errors[:origin]).to include("can't be blank")
    end

    it 'validates uniqueness of job_id scoped to origin and message (truncated to 255 chars)' do
      summary = create(:job_completion_summary)
      job = create(:extraction_job)
      message = 'Test error message'
      
      create(:job_error,
             job_completion_summary: summary,
             job_id: job.id,
             origin: 'TestWorker',
             message: message)
      
      duplicate = build(:job_error,
                       job_completion_summary: summary,
                       job_id: job.id,
                       origin: 'TestWorker',
                       message: message)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:message]).to include("has already been taken")
    end

    it 'allows duplicate message with different job_id' do
      summary = create(:job_completion_summary)
      job1 = create(:extraction_job)
      job2 = create(:extraction_job)
      message = 'Test error message'
      
      create(:job_error,
             job_completion_summary: summary,
             job_id: job1.id,
             origin: 'TestWorker',
             message: message)
      
      different_job = build(:job_error,
                           job_completion_summary: summary,
                           job_id: job2.id,
                           origin: 'TestWorker',
                           message: message)
      
      expect(different_job).to be_valid
    end

    it 'allows duplicate message with different origin' do
      summary = create(:job_completion_summary)
      job = create(:extraction_job)
      message = 'Test error message'
      
      create(:job_error,
             job_completion_summary: summary,
             job_id: job.id,
             origin: 'Worker1',
             message: message)
      
      different_origin = build(:job_error,
                             job_completion_summary: summary,
                             job_id: job.id,
                             origin: 'Worker2',
                             message: message)
      
      expect(different_origin).to be_valid
    end

    it 'allows duplicate when message differs (even if first 255 chars are same)' do
      summary = create(:job_completion_summary)
      job = create(:extraction_job)
      long_message1 = 'A' * 300 + 'X'
      long_message2 = 'A' * 300 + 'Y'
      
      create(:job_error,
             job_completion_summary: summary,
             job_id: job.id,
             origin: 'TestWorker',
             message: long_message1)
      
      different_message = build(:job_error,
                               job_completion_summary: summary,
                               job_id: job.id,
                               origin: 'TestWorker',
                               message: long_message2)
      
      expect(different_message).to be_valid
    end
  end

  describe 'enums' do
    it 'defines process_type enum' do
      expect(JobError.process_types).to eq({ 'extraction' => 0, 'transformation' => 1 })
    end

    it 'can be created with extraction process_type' do
      job_error = create(:job_error, process_type: :extraction)
      expect(job_error.extraction?).to be true
      expect(job_error.transformation?).to be false
    end

    it 'can be created with transformation process_type' do
      job_error = create(:job_error, process_type: :transformation)
      expect(job_error.transformation?).to be true
      expect(job_error.extraction?).to be false
    end
  end

  describe 'stack_trace' do
    it 'accepts an array' do
      stack_trace = ['/app/test.rb:1:in `test_method`', '/app/test.rb:2:in `another_method`']
      job_error = create(:job_error, stack_trace: stack_trace)
      
      expect(job_error.stack_trace).to eq(stack_trace)
    end

    it 'accepts an empty array' do
      job_error = create(:job_error, stack_trace: [])
      
      expect(job_error.stack_trace).to eq([])
    end
  end
end
