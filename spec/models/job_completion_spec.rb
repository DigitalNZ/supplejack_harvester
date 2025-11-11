# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion, type: :model do
  describe 'validations' do
    it 'validates presence of source_name' do
      completion = build(:job_completion, source_name: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:source_name]).to include("can't be blank")
    end

    it 'validates presence of job_type' do
      completion = build(:job_completion, job_type: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:job_type]).to include("can't be blank")
    end

    it 'validates presence of stack_trace' do
      completion = build(:job_completion, stack_trace: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:stack_trace]).to include("can't be blank")
    end

    it 'validates presence of message' do
      completion = build(:job_completion, message: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:message]).to include("can't be blank")
    end

    it 'validates presence of details' do
      completion = build(:job_completion, details: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:details]).to include("can't be blank")
    end

    it 'validates presence of completion_type' do
      completion = build(:job_completion, completion_type: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:completion_type]).to include("can't be blank")
    end

    it 'validates presence of process_type' do
      completion = build(:job_completion, process_type: nil)
      
      expect(completion).not_to be_valid
      expect(completion.errors[:process_type]).to include("can't be blank")
    end

    it 'validates uniqueness of source_id scoped to process_type, job_type, origin, and message_prefix' do
      create(:job_completion, 
             source_id: 'test_id',
             process_type: 'extraction',
             job_type: 'ExtractionJob',
             origin: 'TestWorker',
             message_prefix: 'ERROR')
      
      duplicate = build(:job_completion,
                        source_id: 'test_id',
                        process_type: 'extraction',
                        job_type: 'ExtractionJob',
                        origin: 'TestWorker',
                        message_prefix: 'ERROR')
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_id]).to include("has already been taken")
    end

    it 'allows duplicate source_id with different process_type' do
      create(:job_completion,
             source_id: 'test_id',
             process_type: 'extraction',
             job_type: 'ExtractionJob',
             origin: 'TestWorker',
             message_prefix: 'ERROR')
      
      different_process = build(:job_completion,
                                source_id: 'test_id',
                                process_type: 'transformation',
                                job_type: 'ExtractionJob',
                                origin: 'TestWorker',
                                message_prefix: 'ERROR')
      
      expect(different_process).to be_valid
    end

    it 'allows duplicate source_id with different job_type' do
      create(:job_completion,
             source_id: 'test_id',
             process_type: 'extraction',
             job_type: 'ExtractionJob',
             origin: 'TestWorker',
             message_prefix: 'ERROR')
      
      different_job_type = build(:job_completion,
                                 source_id: 'test_id',
                                 process_type: 'extraction',
                                 job_type: 'TransformationJob',
                                 origin: 'TestWorker',
                                 message_prefix: 'ERROR')
      
      expect(different_job_type).to be_valid
    end

    it 'allows duplicate source_id with different origin' do
      create(:job_completion,
             source_id: 'test_id',
             process_type: 'extraction',
             job_type: 'ExtractionJob',
             origin: 'TestWorker',
             message_prefix: 'ERROR')
      
      different_origin = build(:job_completion,
                               source_id: 'test_id',
                               process_type: 'extraction',
                               job_type: 'ExtractionJob',
                               origin: 'DifferentWorker',
                               message_prefix: 'ERROR')
      
      expect(different_origin).to be_valid
    end

    it 'allows duplicate source_id with different message_prefix' do
      create(:job_completion,
             source_id: 'test_id',
             process_type: 'extraction',
             job_type: 'ExtractionJob',
             origin: 'TestWorker',
             message_prefix: 'ERROR')
      
      different_prefix = build(:job_completion,
                               source_id: 'test_id',
                               process_type: 'extraction',
                               job_type: 'ExtractionJob',
                               origin: 'TestWorker',
                               message_prefix: 'WARN')
      
      expect(different_prefix).to be_valid
    end
  end

  describe 'enums' do
    it 'defines completion_type enum' do
      expect(JobCompletion.completion_types).to eq({ 'error' => 0, 'stop_condition' => 1 })
    end

    it 'defines process_type enum' do
      expect(JobCompletion.process_types).to eq({ 'extraction' => 0, 'transformation' => 1 })
    end

    it 'can be created with error completion_type' do
      completion = create(:job_completion, completion_type: :error)
      expect(completion.error?).to be true
      expect(completion.stop_condition?).to be false
    end

    it 'can be created with stop_condition completion_type' do
      completion = create(:job_completion, :stop_condition)
      expect(completion.stop_condition?).to be true
      expect(completion.error?).to be false
    end

    it 'can be created with extraction process_type' do
      completion = create(:job_completion, process_type: :extraction)
      expect(completion.extraction?).to be true
      expect(completion.transformation?).to be false
    end

    it 'can be created with transformation process_type' do
      completion = create(:job_completion, :transformation)
      expect(completion.transformation?).to be true
      expect(completion.extraction?).to be false
    end
  end

  describe 'scopes' do
    it 'orders by updated_at descending when using order' do
      old_completion = create(:job_completion, updated_at: 2.days.ago)
      recent_completion = create(:job_completion, updated_at: 1.day.ago)
      oldest_completion = create(:job_completion, updated_at: 3.days.ago)
      
      results = JobCompletion.order(updated_at: :desc)
      expect(results.first).to eq(recent_completion)
      expect(results.second).to eq(old_completion)
      expect(results.third).to eq(oldest_completion)
    end
  end

  describe 'instance methods' do
    describe '#stop_condition_name' do
      it 'returns stop_condition_name from details when present' do
        completion = create(:job_completion, :stop_condition)
        expect(completion.stop_condition_name).to eq('test_condition')
      end

      it 'returns nil when stop_condition_name is not in details' do
        completion = create(:job_completion)
        expect(completion.stop_condition_name).to be_nil
      end

      it 'returns nil when details is empty' do
        completion = JobCompletion.new(details: {})
        expect(completion.stop_condition_name).to be_nil
      end
    end

    describe '#stop_condition_type' do
      it 'returns stop_condition_type from details when present' do
        completion = create(:job_completion, :stop_condition)
        expect(completion.stop_condition_type).to eq('user')
      end

      it 'returns nil when stop_condition_type is not in details' do
        completion = create(:job_completion)
        expect(completion.stop_condition_type).to be_nil
      end

      it 'returns nil when details is empty' do
        completion = JobCompletion.new(details: {})
        expect(completion.stop_condition_type).to be_nil
      end
    end
  end
end

