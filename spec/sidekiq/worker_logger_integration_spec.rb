# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/supplejack/job_completion_summary_logger'

RSpec.describe 'Worker Logger Integration' do
  let(:extraction_definition) { create(:extraction_definition) }
  let(:extraction_job) { create(:extraction_job, extraction_definition: extraction_definition) }
  let(:harvest_definition) { create(:harvest_definition, source_id: 'test_source', name: 'Test Source') }

  before do
    extraction_definition.harvest_definitions << harvest_definition
  end

  describe 'EnrichmentExtractionWorker' do
    let(:enrichment_params) { double('enrichment_params', extraction_definition: extraction_definition, extraction_job: extraction_job) }

    it 'calls logger when error is raised' do
      allow(enrichment_params).to receive(:extraction_definition).and_return(extraction_definition)
      allow(enrichment_params).to receive(:extraction_job).and_return(extraction_job)
      
      allow_any_instance_of(EnrichmentExtractionWorker).to receive(:process_enrichment_extraction).and_raise(StandardError.new('Test error'))
      
      expect(JobCompletionSummary::JobCompletionSummaryLogger).to receive(:log_completion).with(
        hash_including(
          worker_class: 'EnrichmentExtractionWorker',
          error: instance_of(StandardError)
        )
      )
      
      expect { EnrichmentExtractionWorker.new.perform(enrichment_params) }.to raise_error(StandardError)
    end
  end

  describe 'FileExtractionWorker' do
    it 'calls logger when error is raised' do
      allow(ExtractionJob).to receive(:find).with(extraction_job.id).and_return(extraction_job)
      
      allow_any_instance_of(FileExtractionWorker).to receive(:process_file_extraction).and_raise(StandardError.new('Test error'))
      
      expect(JobCompletionSummary::JobCompletionSummaryLogger).to receive(:log_completion).with(
        hash_including(
          worker_class: 'FileExtractionWorker',
          error: instance_of(StandardError)
        )
      )
      
      expect { FileExtractionWorker.new.perform(extraction_job.id) }.to raise_error(StandardError)
    end
  end

  describe 'DeleteWorker' do
    let(:destination) { create(:destination) }
    let(:harvest_job) { create(:harvest_job, harvest_definition: harvest_definition) }
    let(:harvest_report) { create(:harvest_report, harvest_job: harvest_job) }

    before do
      allow(harvest_job).to receive(:extraction_job).and_return(extraction_job)
    end

    it 'calls logger when error is raised during delete' do
      allow(Destination).to receive(:find).with(destination.id).and_return(destination)
      allow(HarvestReport).to receive(:find).with(harvest_report.id).and_return(harvest_report)
      
      # Mock the harvest_report to handle the delete_running! call
      allow(harvest_report).to receive(:delete_running!)
      allow(harvest_report).to receive(:increment_delete_workers_completed!)
      allow(harvest_report).to receive(:reload)
      allow(harvest_report).to receive(:delete_workers_completed?).and_return(false)
      
      # Mock the delete execution to raise an error
      allow_any_instance_of(Delete::Execution).to receive(:call).and_raise(StandardError.new('Delete error'))
      
      expect(JobCompletionSummary::JobCompletionSummaryLogger).to receive(:log_completion).with(
        hash_including(
          worker_class: 'DeleteWorker',
          error: instance_of(StandardError)
        )
      )
      
      # DeleteWorker doesn't re-raise errors, so it should complete normally
      # Pass some records to delete so the delete method gets called
      expect { DeleteWorker.new.perform('[{"id": "test"}]', destination.id, harvest_report.id) }.not_to raise_error
    end
  end

  describe 'LoadWorker' do
    let(:harvest_job) { create(:harvest_job, harvest_definition: harvest_definition) }
    let(:harvest_report) { create(:harvest_report, harvest_job: harvest_job) }

    before do
      allow(harvest_job).to receive(:extraction_job).and_return(extraction_job)
    end

    it 'calls logger when error is raised during load' do
      allow(HarvestJob).to receive(:find).with(harvest_job.id).and_return(harvest_job)
      
      # Mock the harvest_report to handle the load_running! call
      allow(harvest_report).to receive(:load_running!)
      allow(harvest_report).to receive(:increment_load_workers_completed!)
      allow(harvest_report).to receive(:reload)
      allow(harvest_report).to receive(:load_workers_completed?).and_return(false)
      
      # Mock the execute_load method to raise an error directly
      allow_any_instance_of(LoadWorker).to receive(:execute_load).and_raise(StandardError.new('Load error'))
      
      expect(JobCompletionSummary::JobCompletionSummaryLogger).to receive(:log_completion).with(
        hash_including(
          worker_class: 'LoadWorker',
          error: instance_of(StandardError)
        )
      )
      
      expect { LoadWorker.new.perform(harvest_job.id, '[{"id": "test"}]') }.to raise_error(StandardError)
    end
  end

  describe 'Stop Condition Logging' do
    let(:enrichment_params) { double('enrichment_params', extraction_definition: extraction_definition, extraction_job: extraction_job) }

    it 'logs stop condition when details contain stop_condition_name' do
      allow(enrichment_params).to receive(:extraction_definition).and_return(extraction_definition)
      allow(enrichment_params).to receive(:extraction_job).and_return(extraction_job)
      
      # Mock the process method to raise an error with stop condition details
      allow_any_instance_of(EnrichmentExtractionWorker).to receive(:process_enrichment_extraction).and_raise(StandardError.new('Stop condition triggered'))
      
      # Mock the logger to capture the call
      allow(JobCompletionSummary::JobCompletionSummaryLogger).to receive(:log_completion).and_call_original
      
      expect { EnrichmentExtractionWorker.new.perform(enrichment_params) }.to raise_error(StandardError)
      
      # Verify that a completion summary was created
      expect(JobCompletionSummary.count).to eq(1)
      summary = JobCompletionSummary.last
      expect(summary.completion_type).to eq('error') # Default when no stop condition details
    end

    it 'logs stop condition when stop condition details are provided' do
      stop_condition_args = {
        worker_class: 'TestWorker',
        definition: extraction_definition,
        job: extraction_job,
        details: {
          stop_condition_name: 'max_records_reached',
          stop_condition_content: 'if records.count > 1000',
          stop_condition_type: 'system'
        }
      }
      
      expect { JobCompletionSummary::JobCompletionSummaryLogger.log_completion(stop_condition_args) }.to change(JobCompletionSummary, :count).by(1)
      
      summary = JobCompletionSummary.last
      expect(summary.completion_type).to eq('stop_condition')
      expect(summary.completion_entries.first['message']).to include("System stop condition 'max_records_reached' was triggered")
    end
  end
end
