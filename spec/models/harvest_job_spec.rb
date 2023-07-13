# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestJob, type: :model do
  let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:) }

  describe '#duration_seconds' do
    it 'returns nil if extraction_job is nil' do
      harvest_job.extraction_job = nil
      expect(harvest_job.duration_seconds).to be_nil
    end

    it 'returns nil if load_jobs is empty' do
      harvest_job.load_jobs = []
      expect(harvest_job.duration_seconds).to be_nil
    end

    it 'returns nil if no load jobs have an end_time' do
      harvest_job.load_jobs.update(end_time: nil)
      expect(harvest_job.duration_seconds).to be_nil
    end

    it 'returns nil if extraction_job has no start_time' do
      harvest_job.extraction_job.update(start_time: nil)
      expect(harvest_job.duration_seconds).to be_nil
    end

    it 'returns the number of seconds between the extraction start_time ignoring idle time between jobs and the max load_job end_time' do
      expect(harvest_job.duration_seconds).to eq 3_960.0
    end

  end

  describe '#transformation_and_load_duration_seconds' do
    it 'returns nil if transformation jobs is empty' do
      harvest_job.transformation_jobs = []
      expect(harvest_job.transformation_and_load_duration_seconds).to be_nil
    end

    it 'returns nil if load_jobs is empty' do
      harvest_job.load_jobs = []
      expect(harvest_job.transformation_and_load_duration_seconds).to be_nil
    end

    it 'returns nil if no load jobs have an end_time' do
      harvest_job.load_jobs.update(end_time: nil)
      expect(harvest_job.transformation_and_load_duration_seconds).to be_nil
    end

    it 'returns nil if transformation jobs have no start_time' do
      harvest_job.transformation_jobs.update(start_time: nil, end_time: nil)
      expect(harvest_job.transformation_and_load_duration_seconds).to be_nil
    end

    it 'returns the number of seconds between the extraction start_time and the max load_job end_time' do
      expect(harvest_job.transformation_and_load_duration_seconds).to eq 360.0
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(harvest_job.name).to eq "#{harvest_job.harvest_definition.name}__job-#{harvest_job.id}"
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:destination) }
  end
end
