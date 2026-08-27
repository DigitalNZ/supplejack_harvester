# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Transformation Definitions' do
  let!(:user) { create(:user) }
  let!(:pipeline) { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:extraction_job)            { create(:extraction_job) }
  let!(:transformation_definition) { create(:transformation_definition, extraction_job:) }

  before do
    sign_in user
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

      it 'does not offer purged extraction jobs in the grouped job dropdown' do
        live = create(:extraction_job)
        purged = create(:extraction_job, purged_at: Time.zone.now)

        post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
          transformation_definition: transformation_definition.attributes
        }

        offered_ids = assigns(:extraction_jobs).flat_map { |_name, jobs| jobs.map(&:last) }
        expect(offered_ids).to include live.id
        expect(offered_ids).not_to include purged.id
      end

      it 'redirects to the pipeline transformation definition path' do
        post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
          transformation_definition: transformation_definition.attributes
        }

        expect(response).to redirect_to pipeline_harvest_definition_transformation_definition_path(pipeline,
                                                                                                   harvest_definition, TransformationDefinition.last)
      end
    end

    context 'when created under a pre-processing block' do
      let!(:preprocess_definition) do
        create(:harvest_definition, kind: :preprocess, pipeline:, transformation_definition: nil, source_id: 'pre-0')
      end

      it 'auto-names the definition after the pre-processing block, not its harvest kind' do
        post pipeline_harvest_definition_transformation_definitions_path(pipeline, preprocess_definition), params: {
          transformation_definition: build(:transformation_definition, pipeline:, extraction_job:).attributes
        }

        definition = TransformationDefinition.order(:id).last
        expect(definition.name).to eq "#{definition.id}_pre-processing-transformation"
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

      it 'redirects to the pipeline path' do
        post pipeline_harvest_definition_transformation_definitions_path(pipeline, harvest_definition), params: {
          transformation_definition: transformation_definition.attributes
        }

        expect(response.status).to eq 302
        follow_redirect!
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

    it 'offers the three description states, and the collapsed one leads' do
      get pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                     transformation_definition)

      expect(response.body).to match(/class="js-description-collapsed"/)
      expect(response.body).to match(/js-description-expanded/)
      expect(response.body).to match(/<textarea[^>]*name="transformation_definition\[description\]"/)
    end

    it 'renders the description as markdown' do
      transformation_definition.update(description: 'Drops **empty** records.')

      get pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                     transformation_definition)

      expect(response.body).to include '<strong>empty</strong>'
    end

    it 'explains that purged preview data was removed, instead of booting the editor' do
      extraction_job.update!(status: 'completed', purged_at: Time.zone.now)

      get pipeline_harvest_definition_transformation_definition_path(
        pipeline, harvest_definition, transformation_definition
      )

      expect(response.body).to include 'Data removed'
      expect(response.body).not_to include 'js-transformation-app'
    end

    it 'does not offer purged extraction jobs in the preview-data dropdown' do
      extraction_definition = harvest_definition.extraction_definition
      live = create(:extraction_job, extraction_definition:)
      purged = create(:extraction_job, extraction_definition:, purged_at: Time.zone.now)

      get pipeline_harvest_definition_transformation_definition_path(
        pipeline, harvest_definition, transformation_definition
      )

      expect(response.body).to include live.name
      expect(response.body).not_to include purged.name
    end

    it 'labels the preview-data dropdown "Preview Data:"' do
      get pipeline_harvest_definition_transformation_definition_path(
        pipeline, harvest_definition, transformation_definition
      )

      expect(response).to be_successful
      expect(response.body).to include 'Preview Data:'
    end

    it 'padlocks retained jobs in the Preview Data select' do
      retained = create(:extraction_job, extraction_definition: harvest_definition.extraction_definition,
                                         status: 'completed', retained_at: Time.zone.now)

      get pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                     transformation_definition)

      expect(response.body).to include("🔒 #{retained.name}")
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

      it 'saves a description on its own' do
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { description: 'Drops empty records.' }
        }

        expect(transformation_definition.reload.description).to eq 'Drops empty records.'
      end

      it 'redirects to the transformation_definitions page' do
        patch pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: { name: 'Flickr' }
        }

        expect(response).to redirect_to(pipeline_harvest_definition_transformation_definition_path(pipeline,
                                                                                                   harvest_definition, transformation_definition))
      end
    end
  end

  describe '#destroy' do
    context 'when the deletion is successful' do
      it 'deletes the Extraction Definition' do
        expect do
          delete pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
            transformation_definition)
        end.to change(TransformationDefinition, :count).by(-1)
      end

      it 'redirects to the pipeline page' do
        delete pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                          transformation_definition)
  
        expect(response).to redirect_to(pipeline_path(pipeline))
        follow_redirect!
        expect(response.body).to include('Transformation Definition deleted successfully')
      end
    end

    context 'when the deletion is not successful' do
      before do
        allow_any_instance_of(TransformationDefinition).to receive(:destroy).and_return(false)
      end

      it 'does not delete the Transformation Definition' do
        expect do
          delete pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
            transformation_definition)
        end.to change(TransformationDefinition, :count).by(0) 
      end

      it 'displays an appropriate message' do
        delete pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition,
                                                                          transformation_definition)
        follow_redirect!
  
        expect(response.body).to include('There was an issue deleting your Transformation Definition')
      end
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

  describe '#clone' do
    context 'when the clone is successful' do
      it 'redirects to the Transformation Definition page' do
        post clone_pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: {
            name: 'copy'
          }
        }
  
        expect(response).to redirect_to pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, TransformationDefinition.last)
      end

      it 'displays an appropriate message' do
        post clone_pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: {
            name: 'copy'
          }
        }

        follow_redirect!

        expect(response.body).to include('Transformation Definition cloned successfully')
      end
    end

    context 'when the clone fails' do
      it 'redirects to the Pipeline page' do
        post clone_pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: {
            name: transformation_definition.name
          }
        }

        expect(response).to redirect_to pipeline_path(pipeline)
      end

      it 'displays an appropriate message' do
        post clone_pipeline_harvest_definition_transformation_definition_path(pipeline, harvest_definition, transformation_definition), params: {
          transformation_definition: {
            name: transformation_definition.name
          }
        }

        follow_redirect!

        expect(response.body).to include('Transformation Definition clone failed. Please confirm that your Transformation Definition name is unique and then try again.')
      end
    end
  end
end
