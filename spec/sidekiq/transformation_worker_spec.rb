# frozen_string_literal: true

require 'rails_helper'
 
RSpec.describe TransformationWorker do
  let!(:pipeline) { create(:pipeline, :figshare) }
  let!(:pipeline_job) { create(:pipeline_job, pipeline:) }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let!(:extraction_job)        { create(:extraction_job, extraction_definition:) }
  let!(:request)                 { create(:request, :figshare_initial_request, extraction_definition:) }

  let!(:transformation_definition) do
    create(:transformation_definition, pipeline:, harvest_definitions: [harvest_definition], extraction_job:, record_selector: '$..items')
  end

  let!(:field_one) do
    create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition: transformation_definition)
  end
  let!(:field_two) do
    create(:field, name: 'source', block: "JsonPath.new('source').on(record).first", transformation_definition: transformation_definition)
  end
  let!(:reject_field) do
    create(:field, kind: 'reject_if', name: 'reject_block', block: 'record["article_id"] == 22947914', transformation_definition:)
  end
  let!(:delete_field) do
    create(:field, kind: 'delete_if', name: 'delete_block', block: 'record["article_id"] == 22947071', transformation_definition:)
  end

  let(:harvest_definition) { pipeline.harvest }
  let!(:harvest_job) { create(:harvest_job, harvest_definition:, extraction_job:, pipeline_job:) }
  let!(:harvest_report) { create(:harvest_report, extraction_status: 'completed', harvest_job:) }

  before do
    stub_request(:get, 'http://www.localhost:3000/harvester/sources?source%5Bsource_id%5D=test')
    .with(
      headers: {
        'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authentication-Token' => 'testkey', 'Content-Type' => 'application/json',
        'User-Agent' => 'Supplejack Harvester v2.0'
      }
    )
    .to_return(status: 200, body: [{ _id: 1 }].to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:put, "http://www.localhost:3000/harvester/sources/1").
      with(
        body: "{\"source\":{\"harvesting\":true}}",
        headers: {
      'Accept'=>'*/*',
      'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authentication-Token'=>'testkey',
      'Content-Type'=>'application/json',
      'User-Agent'=>'Supplejack Harvester v2.0'
        }).
      to_return(status: 200, body: "", headers: {})

    stub_figshare_harvest_requests(request)
    ExtractionWorker.new.perform(extraction_job.id)
  end

  describe '#perform' do
    context 'when the harvest job is cancelled' do
      before do
        allow(HarvestJob).to receive(:find).with(harvest_job.id).and_return(harvest_job)
        allow(harvest_job).to receive(:reload).and_return(harvest_job)
      end
      
      it 'does not queue LoadWorker when harvest job is cancelled' do
        allow(harvest_job).to receive(:cancelled?).and_return(true)
        allow(pipeline_job).to receive(:cancelled?).and_return(false)
        
        expect(LoadWorker).not_to receive(:perform_async_with_priority)
        
        described_class.new.perform(harvest_job.id)
      end
      
      it 'does not queue LoadWorker when pipeline job is cancelled' do
        allow(harvest_job).to receive(:cancelled?).and_return(false)  
        allow(pipeline_job).to receive(:cancelled?).and_return(true)
        
        expect(LoadWorker).not_to receive(:perform_async_with_priority)
        
        described_class.new.perform(harvest_job.id)
      end
    end

    context "when the job starts" do
      it "updates the harvest report to have the transformation start time" do
        TransformationWorker.new.perform(harvest_job.id)
        harvest_report.reload

        expect(harvest_report.transformation_start_time).to be_present
      end
    end

    context "when the job is running" do
      context "when there are no errors in the transformation" do
        it "updates the harvest report with the number of records transformed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.records_transformed).to eq(10)
        end
  
        it "updates the harvest report with the number of records rejected" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.records_rejected).to eq(1)
        end
  
        it "queues the load worker" do
          expect(LoadWorker).to receive(:perform_async_with_priority)
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "notifies the API that harvesting has begun on a particular source" do
          expect(Api::Utils::NotifyHarvesting).to receive(:new).and_call_original
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "increments the load workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload   
  
          expect(harvest_report.load_workers_queued).to eq(1)
        end
  
        it "queues the delete worker" do
          expect(DeleteWorker).to receive(:perform_async_with_priority)
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "increments the delete workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.delete_workers_queued).to eq(1)
        end

        it "marks the transformation as completed" do
          expect(harvest_report.transformation_status).to eq('queued')
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload 
          expect(harvest_report.transformation_status).to eq('completed')
        end
      end

      context "when the transformation has errors" do
        before do
          allow(Transformation::Execution).to receive(:new).and_raise("Error")
        end

        it "updates the harvest report with the number of records transformed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.records_transformed).to eq(0)
        end
  
        it "updates the harvest report with the number of records rejected" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.records_rejected).to eq(0)
        end
  
        it "does not queue the load worker" do
          expect(LoadWorker).not_to receive(:perform_async_with_priority)
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "does not notify the API that harvesting has begun on a particular source" do
          expect(Api::Utils::NotifyHarvesting).not_to receive(:new)
          TransformationWorker.new.perform(harvest_job.id)
        end

        it "still marks the transformation as completed" do
          expect(harvest_report.transformation_status).to eq('queued')
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload 
          expect(harvest_report.transformation_status).to eq('completed')
        end
  
        it "does not increment the load workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload   
  
          expect(harvest_report.load_workers_queued).to eq(0)
        end
  
        it "does not queue the delete worker" do
          expect(DeleteWorker).not_to receive(:perform_async_with_priority)
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "does not increment the delete workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.delete_workers_queued).to eq(0)
        end 
      end

      context "when a field inside of the transformation definition has an error" do
        let!(:error_field) do
          create(:field, name: 'error', block: "JsonPath.new('title').on(no_record).first", transformation_definition: transformation_definition)
        end

        it "updates the harvest report with the number of records transformed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.records_transformed).to eq(10)
        end
  
        it "updates the harvest report with the number of records rejected" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.records_rejected).to eq(1)
        end

        it "still increments the number of transformation workers completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_workers_completed).to eq(1)
        end

        it "still marks the transformation as completed" do
          expect(harvest_report.transformation_status).to eq('queued')
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload 
          expect(harvest_report.transformation_status).to eq('completed')
        end
  
        it "still queues the load worker" do
          expect(LoadWorker).to receive(:perform_async_with_priority)
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "still notifies the API that harvesting has begun on a particular source" do
          expect(Api::Utils::NotifyHarvesting).to receive(:new).and_call_original
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "still increments the load workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload   
  
          expect(harvest_report.load_workers_queued).to eq(1)
        end
  
        it "does still queue the delete worker" do
          expect(DeleteWorker).to receive(:perform_async_with_priority)
          TransformationWorker.new.perform(harvest_job.id)
        end
  
        it "does increments the delete workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload
  
          expect(harvest_report.delete_workers_queued).to eq(1)
        end 
      end

      context "when there is an error extracting the raw records from the extraction job" do
        before do
          allow(Transformation::RawRecordsExtractor).to receive(:new).and_raise("Error")
        end

        it "still increments the number of transformation workers completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_workers_completed).to eq(1)
        end

        it "still marks the transformation as completed" do
          expect(harvest_report.transformation_status).to eq('queued')
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload 
          expect(harvest_report.transformation_status).to eq('completed')
        end
      end

      context "when there is an error with notifying the API about a harvesting job" do
        before do
          allow(Api::Utils::NotifyHarvesting).to receive(:new).and_raise("Error")
        end

        it "still increments the number of load workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.load_workers_queued).to eq(1)
        end
      end
    end

    context "when the job ends" do
      context "when there are no errors in the transformation" do
        it "increments the transformation workers completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_workers_completed).to eq(1)
        end

        it "marks the transformation as completed if all of the workers have completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_end_time).to be_present
        end
      end

      context "when the transformation worker finishes after the load worker and delete worker" do
        let!(:harvest_report) { create(:harvest_report, extraction_status: 'completed', harvest_job:, transformation_status: 'running', load_status: 'running', delete_status: 'running', load_workers_queued: 0, load_workers_completed: 1, delete_workers_queued: 0, delete_workers_completed: 1) }

        it "marks the load and delete completed if the load worker and the delete worker have completed after the transformation worker" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_status).to eq('completed')
          expect(harvest_report.load_status).to eq('completed')
          expect(harvest_report.delete_status).to eq('completed')
        end
      end

      context "when there are errors in the transformation" do
        before do
          allow(Transformation::Execution).to receive(:new).and_raise("Error")
        end

        it "still increments the number of transformation workers completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_workers_completed).to eq(1)
        end

        it "still marks the transformation as completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_end_time).to be_present
        end
      end

      context "when there is an error with a field inside of the transformation definition" do
        let!(:error_field) do
          create(:field, name: 'error', block: "JsonPath.new('title').on(no_record).first", transformation_definition: transformation_definition)
        end

        it "still increments the number of transformation workers completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_workers_completed).to eq(1)
        end

        it "marks the transformation as completed if all of the workers have completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_end_time).to be_present
        end
      end

      context "when there is an error notifying the API about a harvesting job" do
        before do
          allow(Api::Utils::NotifyHarvesting).to receive(:new).and_raise("Error")
        end

        it "still increments the number of transformation workers completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_workers_completed).to eq(1)
        end

        it "still increments the number of load workers queued" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.load_workers_queued).to eq(1)
        end
    
        it "marks the transformation as completed if all of the workers have completed" do
          TransformationWorker.new.perform(harvest_job.id)
          harvest_report.reload

          expect(harvest_report.transformation_end_time).to be_present
        end 
      end
    end
  end
end