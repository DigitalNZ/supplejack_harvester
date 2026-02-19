# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestJob do
  let(:destination)        { create(:destination) }
  let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
  let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(harvest_job.name).to eq "#{harvest_job.id}_harvest"
    end
  end

  describe '#execute_delete_previous_records' do
    let(:pipeline) { create(:pipeline, :figshare) }
    let(:harvest_definition) { pipeline.harvest }

    context 'when valid for deletion' do
      let!(:pipeline_job)   { create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', harvest_definitions_to_run: [pipeline.harvest.id], delete_previous_records: true, status: 'completed') }
      let!(:harvest_job)    { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }
      let!(:harvest_report) { create(:harvest_report, harvest_job:, records_loaded: 100, extraction_status: 'completed', transformation_status: 'completed', load_status: 'completed', delete_status: 'completed') }

      before do
        stub_request(:post, "http://www.localhost:3000/harvester/records/flush").
        with(
          body: "{\"source_id\":\"test\",\"job_id\":\"#{harvest_job.name}\"}",
          headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authentication-Token'=>'testkey',
                'Content-Type'=>'application/json',
                'User-Agent'=>'Supplejack Harvester v2.0'
          }).
        to_return(status: 200, body: "", headers: {})
      end

      it 'tells the destination to delete previously harvested records' do
        expect(DeletePreviousRecords::Execution).to receive(:new).exactly(1).times.and_call_original

        harvest_job.execute_delete_previous_records
      end
    end

    context 'when invalid for deletion' do
      it 'does not tell the destination to delete previously harvested records if it is not in the pipeline job settings' do
        pipeline_job = create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', harvest_definitions_to_run: [pipeline.harvest.id])
        harvest_job = create(:harvest_job, :completed, harvest_definition:, pipeline_job:)
        harvest_report = create(:harvest_report, harvest_job:, records_loaded: 10)

        expect(DeletePreviousRecords::Execution).to receive(:new).exactly(0).times.and_call_original

        harvest_job.execute_delete_previous_records
      end

      it 'does not tell the destination to delete previously harvested records when there have been 0 records harvested' do
        pipeline_job = create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', harvest_definitions_to_run: [pipeline.harvest.id], delete_previous_records: true)
        harvest_job = create(:harvest_job, :completed, harvest_definition:, pipeline_job:)
        harvest_report = create(:harvest_report, harvest_job:, records_loaded: 0)

        expect(DeletePreviousRecords::Execution).to receive(:new).exactly(0).times.and_call_original

        harvest_job.execute_delete_previous_records
      end

      it 'does not tell the destination to delete previously harvested records when the harvest hasnt completed' do
        pipeline_job = create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', harvest_definitions_to_run: [pipeline.harvest.id], delete_previous_records: true)
        harvest_job = create(:harvest_job, harvest_definition:, pipeline_job:)
        harvest_report = create(:harvest_report, harvest_job:, records_loaded: 10)

        expect(DeletePreviousRecords::Execution).to receive(:new).exactly(0).times.and_call_original

        harvest_job.execute_delete_previous_records
      end

      it 'does not tell the destination to delete previously harvested records when the pipeline job has been cancelled' do
        pipeline_job = create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', harvest_definitions_to_run: [pipeline.harvest.id], delete_previous_records: true, status: 'cancelled')
        harvest_job = create(:harvest_job, harvest_definition:, pipeline_job:)
        harvest_report = create(:harvest_report, :completed, harvest_job:, records_loaded: 10)

        expect(DeletePreviousRecords::Execution).to receive(:new).exactly(0).times.and_call_original

        harvest_job.execute_delete_previous_records
      end

      it 'does not tell the destination to delete previously harvested records from an enrichment' do
        pipeline_job = create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', harvest_definitions_to_run: [pipeline.harvest.id], delete_previous_records: true, status: 'cancelled')

        harvest_definition = create(:harvest_definition, kind: 'enrichment', pipeline:)

        harvest_job = create(:harvest_job, harvest_definition:, pipeline_job:)
        harvest_report = create(:harvest_report, :completed, harvest_job:, records_loaded: 10)

        expect(DeletePreviousRecords::Execution).to receive(:new).exactly(0).times.and_call_original

        harvest_job.execute_delete_previous_records
      end
    end
  end
end
