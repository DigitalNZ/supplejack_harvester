# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestReport, type: :model do
  let(:pipeline)           { create(:pipeline) }
  let(:destination)        { create(:destination) }
  let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
  subject                  { create(:harvest_report, pipeline_job:, harvest_job:) }

  describe 'associations' do
    it { is_expected.to belong_to(:pipeline_job) }
  end

  describe 'status checks' do
    ['extraction', 'transformation', 'load'].each do |type|
      described_class::STATUSES.each do |status|
        it "defines the check #{type}_#{status}?" do
          subject.send("#{type}_status=", status)
          expect(subject.send("#{type}_#{status}?")).to be true
          subject.send("#{type}_status=", described_class::STATUSES.without(status).sample)
          expect(subject.send("#{type}_#{status}?")).to be false
        end

        it "defines a way to update the status with #{type}_#{status}!" do
          subject.send("#{type}_status=", status)
          expect(subject.send("#{type}_#{status}!")).to be true
          subject.reload
          expect(subject.send("#{type}_#{status}?")).to be true
        end
      end
    end
  end
  
  describe '#increment_pages_extracted!' do
    it 'increments the pages extracted count' do
      expect(subject.pages_extracted).to eq 0
      subject.increment_pages_extracted!
      subject.reload
      expect(subject.pages_extracted).to eq 1
    end
  end

  describe '#increment_records_transformed!' do
    it 'increments the records transformed count' do
      expect(subject.records_transformed).to eq 0
      subject.increment_records_transformed!(10)
      subject.reload
      expect(subject.records_transformed).to eq 10
    end
  end

  describe '#increment_records_loaded!' do
    it 'increments the records loaded count' do
      expect(subject.records_loaded).to eq 0
      subject.increment_records_loaded!
      subject.reload
      expect(subject.records_loaded).to eq 1
    end
  end

  describe '#increment_records_rejected!' do
    it 'increments the records rejected count' do
      expect(subject.records_rejected).to eq 0
      subject.increment_records_rejected!(5)
      subject.reload
      expect(subject.records_rejected).to eq 5
    end
  end
  
  describe '#increment_records_deleted!' do
    it 'increments the records deleted count' do
      expect(subject.records_deleted).to eq 0
      subject.increment_records_deleted!
      subject.reload
      expect(subject.records_deleted).to eq 1
    end
  end
  
  describe '#increment_transformation_workers_queued!' do
    it 'increments the transformation workers queued count count' do
      expect(subject.transformation_workers_queued).to eq 0
      subject.increment_transformation_workers_queued!
      subject.reload
      expect(subject.transformation_workers_queued).to eq 1
    end
  end
  
  describe '#increment_transformation_workers_completed!' do
    it 'increments the transformation workers completed count count' do
      expect(subject.transformation_workers_completed).to eq 0
      subject.increment_transformation_workers_completed!
      subject.reload
      expect(subject.transformation_workers_completed).to eq 1
    end
  end
  
  describe '#increment_load_workers_queued!' do
    it 'increments the load workers queued count count' do
      expect(subject.load_workers_queued).to eq 0
      subject.increment_load_workers_queued!
      subject.reload
      expect(subject.load_workers_queued).to eq 1
    end
  end
  
  describe '#increment_load_workers_completed!' do
    it 'increments the load workers completed count count' do
      expect(subject.load_workers_completed).to eq 0
      subject.increment_load_workers_completed!
      subject.reload
      expect(subject.load_workers_completed).to eq 1
    end
  end

  describe '#increment_delete_workers_queued!' do
    it 'increments the delete workers queued count count' do
      expect(subject.delete_workers_queued).to eq 0
      subject.increment_delete_workers_queued!
      subject.reload
      expect(subject.delete_workers_queued).to eq 1
    end
  end
  
  describe '#increment_delete_workers_completed!' do
    it 'increments the delete workers completed count count' do
      expect(subject.delete_workers_completed).to eq 0
      subject.increment_delete_workers_completed!
      subject.reload
      expect(subject.delete_workers_completed).to eq 1
    end
  end

  describe '#duration_seconds' do
    let(:nil_report) { create(:harvest_report, pipeline_job:, harvest_job:) }
    let(:in_progress_report) do
      create(:harvest_report, pipeline_job:, harvest_job:, 
                              extraction_start_time: 20.minutes.ago,
                              extraction_updated_time: 15.minutes.ago,
                              transformation_start_time: 18.minutes.ago,
                              transformation_updated_time: 16.minutes.ago,
                              load_start_time: 14.minutes.ago,
                              load_updated_time: 12.minutes.ago
      )
    end

    it 'returns nil if there are no times' do
      expect(nil_report.duration_seconds).to eq nil
    end

    it 'returns the time between the extraction start and the latest updated time between the extraction, transformation, and load' do
      expect(in_progress_report.duration_seconds).to eq 480
    end
  end

  describe '#status' do
    let(:queued)      { create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'queued', transformation_status: 'queued', load_status: 'queued', delete_status: 'queued') }
    let(:running_one) { create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'running', transformation_status: 'queued', load_status: 'queued', delete_status: 'queued') }
    let(:running_two) { create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'completed', transformation_status: 'queued', load_status: 'queued', delete_status: 'queued') }
    let(:completed) { create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'completed', transformation_status: 'completed', load_status: 'completed', delete_status: 'completed') }

    it 'returns queued if all processes are queued' do
      expect(queued.status).to eq 'queued'
    end

    it 'returns running if anything is running' do
      expect(running_one.status).to eq 'running'
    end

    it 'returns running if something is completed and something is queued' do
      expect(running_two.status).to eq 'running'
    end

    it 'returns completed if all processes are completed' do
      expect(completed.status).to eq 'completed'
    end
  end
end