# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Parameters' do
  let(:user)                       { create(:user) }
  let(:pipeline)                   { create(:pipeline) }
  let(:harvest_definition)         { create(:harvest_definition, extraction_definition:, pipeline:) }
  let!(:extraction_definition)     { create(:extraction_definition, pipeline:) }
  let!(:request)                   { create(:request, extraction_definition:) }

  before do
    sign_in user
  end

  describe '#create' do
    let(:parameter) { build(:parameter, request:, name: 'key', content: 'value') }

    context 'with valid parameters' do
      it 'creates a new parameter' do
        expect do
          post pipeline_harvest_definition_extraction_definition_request_parameters_path(pipeline, harvest_definition, extraction_definition, request), params: {
            parameter: parameter.attributes
          }
        end.to change(Parameter, :count).by(1)
      end

      it 'updates the extraction definition last edited by' do
        post pipeline_harvest_definition_extraction_definition_request_parameters_path(pipeline, harvest_definition, extraction_definition, request), params: {
          parameter: parameter.attributes
        }

        expect(extraction_definition.reload.last_edited_by).to eq user
      end

      it 'returns a JSON object representing the new parameter' do
        post pipeline_harvest_definition_extraction_definition_request_parameters_path(pipeline, harvest_definition, extraction_definition, request), params: {
          parameter: parameter.attributes
        }

        parameter = response.parsed_body

        expect(parameter['name']).to eq 'key'
        expect(parameter['content']).to eq 'value'
      end
    end
  end

  describe '#update' do
    let(:parameter) { create(:parameter, request:) }

    context 'with valid parameters' do
      it 'updates the parameter' do
        patch pipeline_harvest_definition_extraction_definition_request_parameter_path(pipeline, harvest_definition, extraction_definition, request, parameter), params: {
          parameter: { name: 'X-Forwarded-For', content: 'ab.cd.ef.gh' }
        }

        expect(parameter.reload.name).to eq 'X-Forwarded-For'
        expect(parameter.content).to eq 'ab.cd.ef.gh'
      end

      it 'updates the extraction definition last edited by' do
        patch pipeline_harvest_definition_extraction_definition_request_parameter_path(pipeline, harvest_definition, extraction_definition, request, parameter), params: {
          parameter: { name: 'X-Forwarded-For', content: 'ab.cd.ef.gh' }
        }

        expect(extraction_definition.reload.last_edited_by).to eq user
      end

      it 'returns a JSON hash of the updated parameter' do
        patch pipeline_harvest_definition_extraction_definition_request_parameter_path(pipeline, harvest_definition, extraction_definition, request, parameter), params: {
          parameter: { name: 'X-Forwarded-For', content: 'ab.cd.ef.gh' }
        }

        expect(response.parsed_body['name']).to eq 'X-Forwarded-For'
        expect(response.parsed_body['content']).to eq 'ab.cd.ef.gh'
      end
    end
  end

  describe '#destroy' do
    let!(:parameter) { create(:parameter, request:) }

    it 'deletes the parameter' do
      expect do
        delete pipeline_harvest_definition_extraction_definition_request_parameter_path(pipeline, harvest_definition,
                                                                                        extraction_definition, request, parameter)
      end.to change(Parameter, :count).by(-1)
    end

    it 'updates the extraction definition last edited by' do
      delete pipeline_harvest_definition_extraction_definition_request_parameter_path(
        pipeline, harvest_definition, extraction_definition, request, parameter
      )

      expect(extraction_definition.reload.last_edited_by).to eq user
    end

    it 'returns a successful response' do
      delete pipeline_harvest_definition_extraction_definition_request_parameter_path(pipeline, harvest_definition,
                                                                                      extraction_definition, request, parameter)

      expect(response).to have_http_status :ok
    end
  end
end
