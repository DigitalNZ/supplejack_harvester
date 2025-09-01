# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::RecordExtraction do
  let(:destination)           { create(:destination) }
  let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:) }

  let!(:request) { create(:request, extraction_definition:) }


  describe '#extract' do
    context 'when the enrichment is not scheduled after a harvest' do
      before do
        stub_request(:get, "#{destination.url}/harvester/records")
          .with(
            query: {
              'api_key' => 'testkey',
              'search' => {
                'status' => 'active',
                'fragments.source_id' => 'test'
              },
              'search_options' => {
                'page' => 1
              }
            },
            headers: fake_json_headers
          ).to_return(fake_response('test_api_records_1'))
      end

      let(:subject) { described_class.new(request, 1) }

      it 'returns an extracted document from a Supplejack API' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end

    context 'when the extraction definition specifies specific fields and subdocuments' do
      let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, fields: 'id,internal_identifier', include_sub_documents: false) }

      before do
        stub_request(:get, "http://www.localhost:3000/harvester/records?api_key=testkey&fields%5B%5D=id&fields%5B%5D=internal_identifier&record_includes=null&search%5Bfragments.source_id%5D=test&search%5Bstatus%5D=active&search_options%5Bpage%5D=1").
        with(
          headers: {
         'Accept'=>'*/*',
         'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
         'Content-Type'=>'application/json',
         'User-Agent'=>'Supplejack Harvester v2.0'
          }).to_return(fake_response('test_api_records_1'))
      end

      let(:subject) { described_class.new(request, 1) }

      it 'specifies the requested fields in the API request' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end

    context "when the pipeline job is set to skip previously enriched records" do
      let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:harvest_definition) { create(:harvest_definition, source_id: "enrichment_source_id", kind: 1) }
      let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:) }
      let(:pipeline_job) { create(:pipeline_job, skip_previously_enriched: true) }

      before do
        stub_request(:get, "http://www.localhost:3000/harvester/records?api_key=testkey&search%5Bfragments.source_id%5D=test&search%5Bstatus%5D=active&search_options%5Bpage%5D=1&exclude_source_id=enrichment_source_id").
        with(
          headers: {
         'Accept'=>'*/*',
         'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
         'Content-Type'=>'application/json',
         'User-Agent'=>'Supplejack Harvester v2.0'
          }).to_return(fake_response('test_api_records_1'))
      end
      let(:subject) { described_class.new(request, 1, harvest_job) }

      it 'specifies the source_id to exclude in the API request' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end

    context 'when the enrichment is scheduled after a harvest' do
      let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, extraction_definition:) }
      let(:harvest_job)        do
        create(:harvest_job, :completed, harvest_definition:, pipeline_job:, target_job_id: 'harvest-job-1')
      end
      let(:subject) { described_class.new(request, 1, harvest_job) }

      before do
        stub_request(:get, "#{destination.url}/harvester/records")
          .with(
            query: {
              'api_key' => 'testkey',
              'search' => {
                'status' => 'active',
                'fragments.job_id' => 'harvest-job-1'
              },
              'search_options' => {
                'page' => 1
              }
            },
            headers: fake_json_headers
          ).to_return(fake_response('test_api_records_1'))
      end

      it 'returns an extraction document from a particular job from a Supplejack API' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end
  end

  describe '#fragment_filter' do
    context 'when harvest_job has a target_job_id' do
      let(:pipeline) { create(:pipeline, name: 'TestPipeline') }
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, extraction_definition:) }
      let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:, target_job_id: 'test-job-123') }
      let(:subject) { described_class.new(request, 1, harvest_job) }

      it 'returns a hash with fragments.job_id mapped to the target_job_id' do
        expect(subject.send(:fragment_filter)).to eq({ 'fragments.job_id' => 'test-job-123' })
      end
    end

    context 'when harvest_job has a pipeline_job with an automation_step' do
      let(:automation) { create(:automation) }
      let(:automation_step) { create(:automation_step, automation:) }
      let(:pipeline) { create(:pipeline, name: 'TestPipeline') }
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:, automation_step:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, extraction_definition:) }
      let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:subject) { described_class.new(request, 1, harvest_job) }

      before do
        # Create an automation setup with harvest jobs
        other_automation_step = create(:automation_step, automation:)
        other_pipeline = create(:pipeline, name: 'OtherTestPipeline')
        other_pipeline_job = create(:pipeline_job, pipeline: other_pipeline, automation_step: other_automation_step)
        other_harvest_definition = create(:harvest_definition, pipeline: other_pipeline)
        
        create(:harvest_job, name: 'job1__harvest-abc', pipeline_job: other_pipeline_job, harvest_definition: other_harvest_definition)
        create(:harvest_job, name: 'job2__harvest-xyz', pipeline_job: other_pipeline_job, harvest_definition: other_harvest_definition)
        create(:harvest_job, name: 'job3__enrichment-abc', pipeline_job: other_pipeline_job, harvest_definition: other_harvest_definition)
      end

      it 'returns a hash with fragments.job_id mapped to job names with __harvest-' do
        result = subject.send(:fragment_filter)
        expect(result).to have_key('fragments.job_id')
        
        # Check that all job names include '__harvest-'
        expect(result['fragments.job_id']).to all(include('__harvest-'))
        
        # Ensure non-harvest job names are not included
        expect(result['fragments.job_id']).not_to include(match('job3__enrichment-abc'))
      end
    end

    context 'when neither target_job_id nor automation_step are present' do
      let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, source_id: 'source-123') }
      let(:request) { create(:request, extraction_definition:) }
      let(:subject) { described_class.new(request, 1) }

      it 'returns a hash with fragments.source_id mapped to the extraction_definition source_id' do
        expect(subject.send(:fragment_filter)).to eq({ 'fragments.source_id' => 'source-123' })
      end
    end
  end
end
