# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransformationWorker, type: :job do
  let(:pipeline) { create(:pipeline, :figshare) }
  let(:harvest_definition) { pipeline.harvest }
  let(:destination) { create(:destination) }
  let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }
  let(:extraction_job) { create(:extraction_job, harvest_job:) }
  let!(:harvest_report) { create(:harvest_report, harvest_job:, pipeline_job:) }
  
  let!(:field) do
    create(
      :field,
      name: 'title',
      block: "JsonPath.new('title').on(record).first",
      transformation_definition: harvest_definition.transformation_definition
    )
  end

  before do
    # Stub the transform_records method to return predictable data
    allow_any_instance_of(described_class).to receive(:transform_records).and_return([
      double(to_hash: { 'title' => 'Test Record 1', 'rejection_reasons' => nil, 'deletion_reasons' => nil }),
      double(to_hash: { 'title' => 'Test Record 2', 'rejection_reasons' => nil, 'deletion_reasons' => nil })
    ])
    
    # Stub API calls to prevent HTTP requests
    allow_any_instance_of(Api::Utils::NotifyHarvesting).to receive(:call)
  end

  describe '#perform' do
    context 'when the harvest job is cancelled' do
      before do
        # Mock the reload method to return the same objects with cancelled status
        allow(HarvestJob).to receive(:find).with(harvest_job.id).and_return(harvest_job)
        allow(harvest_job).to receive(:reload).and_return(harvest_job)
      end
      
      it 'does not queue LoadWorker when harvest job is cancelled' do
        allow(harvest_job).to receive(:cancelled?).and_return(true)
        allow(pipeline_job).to receive(:cancelled?).and_return(false)
        
        expect(LoadWorker).not_to receive(:perform_async_with_priority)
        expect(harvest_report).not_to receive(:increment_records_transformed!)
        
        described_class.new.perform(harvest_job.id, 1)
      end
      
      it 'does not queue LoadWorker when pipeline job is cancelled' do
        allow(harvest_job).to receive(:cancelled?).and_return(false)  
        allow(pipeline_job).to receive(:cancelled?).and_return(true)
        
        expect(LoadWorker).not_to receive(:perform_async_with_priority)
        expect(harvest_report).not_to receive(:increment_records_transformed!)
        
        described_class.new.perform(harvest_job.id, 1)
      end
    end
    
    context 'when the harvest job is not cancelled' do
      before do
        allow(HarvestJob).to receive(:find).with(harvest_job.id).and_return(harvest_job)
        allow(harvest_job).to receive(:reload).and_return(harvest_job)
        allow(harvest_job).to receive(:cancelled?).and_return(false)
        allow(pipeline_job).to receive(:cancelled?).and_return(false)
      end
      
      it 'queues LoadWorker when not cancelled' do
        expect(LoadWorker).to receive(:perform_async_with_priority)
        
        described_class.new.perform(harvest_job.id, 1)
      end
      
      it 'updates harvest report when not cancelled' do
        expect(harvest_report).to receive(:increment_records_transformed!).with(2)
        
        described_class.new.perform(harvest_job.id, 1)
      end
    end
  end
end