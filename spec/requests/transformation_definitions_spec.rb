# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Transformation Definitions' do
  let!(:user) { create(:user) }
  let!(:pipeline) { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:extraction_job)            { create(:extraction_job) }
  let(:transformation_definition) { create(:transformation_definition, extraction_job:) }

  before do
    sign_in user
  end

  describe '#new' do
    it 'renders the new form' do
      get new_pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, kind: 'harvest')

      expect(response).to have_http_status :ok
    end
  end

  describe '#edit' do
    it 'renders the form' do
      get edit_pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                          transformation_definition)

      expect(response).to have_http_status :ok
    end
  end

  describe '#create' do
    context 'with valid parameters' do
      let(:transformation_definition) { build(:transformation_definition, pipeline:, extraction_job:) }

      it 'creates a new transformation_definition' do
        expect do
          post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
            transformation_definition: transformation_definition.attributes
          }
        end.to change(TransformationDefinition, :count).by(1)
      end

      it 'stores the user who created it' do
        post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
          transformation_definition: transformation_definition.attributes
        }

        expect(TransformationDefinition.last.last_edited_by).to eq user
      end

      it 'redirects to the pipeline transformation definition path' do
        post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
          transformation_definition: transformation_definition.attributes
        }

        expect(response).to redirect_to pipeline_harvest_definition_transformation_definition_path(pipeline,
                                                                                                   harvest_definition, TransformationDefinition.last)
      end
    end

    context 'with invalid parameters' do
      let(:transformation_definition) { build(:transformation_definition) }

      it 'does not create a new transformation_definition' do
        expect do
          post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
            transformation_definition: transformation_definition.attributes
          }
        end.not_to change(TransformationDefinition, :count)
      end

      it 'rerenders the new form' do
        post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
          transformation_definition: transformation_definition.attributes
        }

        expect(response).to have_http_status :ok
        expect(response.body).to include 'There was an issue creating your Transformation Definition'
      end
    end
  end

  describe '#show' do
    let(:transformation_definition) { create(:transformation_definition, pipeline:, extraction_job:) }

    it 'shows the details for a transformation_definition' do
      get pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                     transformation_definition)

      expect(response).to have_http_status :ok
    end
  end

  describe '#update' do
    context 'with valid parameters' do
      it 'updates the transformation_definition' do
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { name: 'Flickr' }
        }

        transformation_definition.reload

        expect(transformation_definition.name).to eq 'Flickr'
      end

      it 'stores the user who updated it' do
        sign_out(user)
        new_user = create(:user)
        sign_in(new_user)
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { name: 'Flickr' }
        }

        expect(transformation_definition.reload.last_edited_by).to eq new_user
      end

      it 'redirects to the transformation_definitions page' do
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { name: 'Flickr' }
        }

        expect(response).to redirect_to(pipeline_harvest_definition_transformation_definition_path(pipeline,
                                                                                                   harvest_definition, transformation_definition))
      end
    end

    context 'with invalid paramaters' do
      it 'does not update the transformation_definition' do
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { record_selector: nil }
        }

        transformation_definition.reload

        expect(transformation_definition.record_selector).not_to be_nil
      end

      it 're renders the form' do
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { record_selector: nil }
        }

        expect(response.body).to include transformation_definition.name_in_database
      end
    end
  end

  describe '#destroy' do
    it 'destroys the transformation_definition' do
      delete pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                        transformation_definition)

      expect(response).to redirect_to(pipeline_path(pipeline))
      follow_redirect!
      expect(response.body).to include('Transformation Definition deleted successfully')
    end

    it 'displays a message when failing' do
      allow_any_instance_of(TransformationDefinition).to receive(:destroy).and_return false
      delete pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                        transformation_definition)
      follow_redirect!

      expect(response.body).to include('There was an issue deleting your Transformation Definition')
    end
  end

  describe '#test' do
    let(:pipeline)                { create(:pipeline, :figshare) }
    let(:extraction_definition)   { pipeline.harvest.extraction_definition }
    let(:extraction_job)          { create(:extraction_job, extraction_definition:) }
    let(:request)                 { create(:request, :figshare_initial_request, extraction_definition:) }
    let(:subject)                 do
      create(:transformation_definition, pipeline:, extraction_job:, record_selector: '$..items')
    end

    before do
      # that's to test the display of results
      stub_figshare_harvest_requests(request)
      ExtractionWorker.new.perform(extraction_job.id)
    end

    it 'returns a JSON object containing the result of the selected job and the applied record selector' do
      post test_pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
        transformation_definition: subject.attributes
      }

      expect(response).to have_http_status :ok

      json_data = response.parsed_body['result']
      expected_keys = %w[article_id title DOI description type url published_date authors links defined_type
                         modified_date]

      expected_keys.each do |key|
        expect(json_data).to have_key(key)
      end
    end
  end
end
