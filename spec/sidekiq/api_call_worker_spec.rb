require 'rails_helper'

RSpec.describe ApiCallWorker do
  let(:automation) { create(:automation) }
  let(:pipeline) { create(:pipeline) }
  let(:pipeline_step) { create(:automation_step, automation: automation, pipeline: pipeline, position: 0) }
  let(:pipeline_job) { create(:pipeline_job, automation_step: pipeline_step, pipeline: pipeline) }
  let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, name: "harvest_test__job-123") }
  let(:api_step) { create(:automation_step, automation: automation, pipeline: nil, step_type: 'api_call', position: 1, api_url: 'https://api.example.com', api_method: 'POST', api_body: '{"job_ids": "{{job_ids}}"}') }
  let(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
        instance_double(Net::HTTPSuccess, code: '200', body: 'Success', to_hash: {})
      )
    end

    context 'with JSON body interpolation' do
      before do
        pipeline_job # Create the pipeline job
        harvest_job  # Create the harvest job
        # Mock the collect_pipeline_job_ids method to return harvest job names
        allow_any_instance_of(ApiCallWorker).to receive(:collect_pipeline_job_ids).and_return([harvest_job.name])
      end

      it 'correctly interpolates job_ids in simple JSON body' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: '{"job_ids": {{job_ids}}}'
        )

        expect_any_instance_of(Net::HTTP::Post).to receive(:body=) do |_, body|
          expect(JSON.parse(body)).to eq({ "job_ids" => [harvest_job.name] })
        end

        worker.perform(api_step.id)
      end

      it 'interpolates job_ids in nested JSON structure' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: '{"data": {"jobs": {{job_ids}}, "other": "value"}}'
        )

        expect_any_instance_of(Net::HTTP::Post).to receive(:body=) do |_, body|
          expect(JSON.parse(body)).to eq({ "data" => { "jobs" => [harvest_job.name], "other" => "value" } })
        end

        worker.perform(api_step.id)
      end

      it 'interpolates job_ids in arrays' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: '{"data": [{{job_ids}}, "other"]}'
        )

        expect_any_instance_of(Net::HTTP::Post).to receive(:body=) do |_, body|
          expect(JSON.parse(body)).to eq({ "data" => [[harvest_job.name], "other"] })
        end

        worker.perform(api_step.id)
      end

      it 'handles multiple job_ids placeholders' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: '{"first": {{job_ids}}, "second": {"nested": {{job_ids}}}}'
        )

        expect_any_instance_of(Net::HTTP::Post).to receive(:body=) do |_, body|
          expect(JSON.parse(body)).to eq({ 
            "first" => [harvest_job.name], 
            "second" => { "nested" => [harvest_job.name] } 
          })
        end

        worker.perform(api_step.id)
      end

      it 'handles non-JSON bodies with job_ids interpolation' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: 'job_ids={{job_ids}}'
        )

        expect_any_instance_of(Net::HTTP::Post).to receive(:body=).with(
          "job_ids=[\"#{harvest_job.name}\"]"
        )

        worker.perform(api_step.id)
      end

      it 'leaves JSON body unchanged if no interpolation needed' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: '{"data": "test"}'
        )

        expect_any_instance_of(Net::HTTP::Post).to receive(:body=) do |_, body|
          expect(JSON.parse(body)).to eq({ "data" => "test" })
        end

        worker.perform(api_step.id)
      end

      it 'handles invalid JSON gracefully' do
        api_step.update(
          api_url: 'https://api.example.com',
          api_method: 'POST',
          api_body: '{invalid json with {{job_ids}}'
        )

        # The actual implementation is missing the closing bracket
        expect_any_instance_of(Net::HTTP::Post).to receive(:body=).with(
          "{invalid json with [\"#{harvest_job.name}\"]"
        )

        worker.perform(api_step.id)
      end
    end
  end
end 