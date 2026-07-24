# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ExtractionDefinitions' do
  let(:user)                   { create(:user) }
  let(:pipeline)               { create(:pipeline) }
  let!(:extraction_definition) { create(:extraction_definition) }
  let!(:harvest_definition)    { create(:harvest_definition, extraction_definition:, pipeline:) }

  before do
    sign_in user
  end

  describe '#show' do
    context 'when the extraction definition belongs to a harvest' do
      let!(:requests) { create_list(:request, 2, extraction_definition:) }

      it 'renders the harvest settings modal' do
        get pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition,
                                                                   extraction_definition)

        expect(response.body).to include 'Paginated'
        expect(response.body).not_to include 'Target Source ID'
      end
    end

    context 'when the extraction definition belongs to a pre-processing block' do
      let(:preprocess_extraction_definition) { create(:extraction_definition, pipeline:) }
      let(:preprocess_definition) do
        create(:harvest_definition, kind: :preprocess, pipeline:,
                                    extraction_definition: preprocess_extraction_definition, source_id: 'pre-0')
      end

      let!(:requests) { create_list(:request, 2, extraction_definition: preprocess_extraction_definition) }

      it 'renders the harvest settings modal' do
        get pipeline_harvest_definition_extraction_definition_path(pipeline, preprocess_definition,
                                                                   preprocess_extraction_definition)

        expect(response.body).to include 'Paginated'
        expect(response.body).not_to include 'Target Source ID'
      end
    end

    context 'when the extraction definition belongs to an enrichment' do
      let(:enrichment_extraction_definition) do
        create(:extraction_definition, :enrichment, pipeline:, destination: create(:destination))
      end
      let(:enrichment_definition) do
        create(:harvest_definition, kind: :enrichment, pipeline:,
                                    extraction_definition: enrichment_extraction_definition)
      end

      let!(:requests) { create_list(:request, 2, extraction_definition: enrichment_extraction_definition) }

      it 'renders the enrichment settings modal' do
        get pipeline_harvest_definition_extraction_definition_path(pipeline, enrichment_definition,
                                                                   enrichment_extraction_definition)

        expect(response.body).to include 'Target Source ID'
        expect(response.body).not_to include 'Paginated'
        expect(response.body).to include 'Preview Data:'
        expect(response.body).not_to include 'Preview harvested records from'
      end
    end
  end

  describe '#create' do
    context 'with valid parameters' do
      let(:extraction_definition2) { build(:extraction_definition, pipeline:) }

      it 'creates a new extraction definition' do
        expect do
          post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
            extraction_definition: extraction_definition2.attributes
          }
        end.to change(ExtractionDefinition, :count).by(1)
      end

      it 'stores the user who created it' do
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes
        }

        expect(ExtractionDefinition.last.last_edited_by).to eq user
      end

      it 'creates 2 requests for the new extraction definition' do
        expect do
          post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
            extraction_definition: extraction_definition2.attributes
          }
        end.to change(Request, :count).by(2)

        expect(ExtractionDefinition.last.requests.count).to eq 2
      end

      it 'redirects to the extraction definition' do
        extraction_definition2 = build(:extraction_definition, pipeline:)
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes
        }

        expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_path(pipeline,
                                                                                               harvest_definition, ExtractionDefinition.last)
      end

      it 'associates an extraction definition with a provided harvest definition' do
        harvest_definition = create(:harvest_definition, pipeline:, extraction_definition: nil)
        expect(harvest_definition.extraction_definition).to be_nil

        extraction_definition2 = build(:extraction_definition, pipeline:)
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes.merge(harvest_definition_id: harvest_definition.id)
        }

        harvest_definition.reload

        expect(harvest_definition.extraction_definition).not_to be_nil
      end
    end

    context 'when created under a pre-processing block' do
      let!(:preprocess_definition) do
        create(:harvest_definition, kind: :preprocess, pipeline:, extraction_definition: nil, source_id: 'pre-0')
      end

      it 'auto-names the definition after the pre-processing block, not its harvest kind' do
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, preprocess_definition), params: {
          extraction_definition: build(:extraction_definition, pipeline:).attributes
        }

        definition = ExtractionDefinition.order(:id).last
        expect(definition.name).to eq "#{definition.id}_pre-processing-extraction"
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new extraction definition' do
        extraction_definition2 = build(:extraction_definition, format: nil, pipeline:)
        expect do
          post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
            extraction_definition: extraction_definition2.attributes
          }
        end.not_to change(ExtractionDefinition, :count)
      end

      it 'renders the form again' do
        extraction_definition2 = build(:extraction_definition, format: nil, pipeline:)
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes
        }

        expect(response.status).to eq 302
        follow_redirect!
        expect(response.body).to include 'There was an issue creating your Extraction Definition'
      end
    end
  end

  describe '#update' do
    let!(:request_one) { create(:request, extraction_definition:) }
    let!(:request_two) { create(:request, extraction_definition:) }

    context 'with valid parameters' do
      it 'updates the extraction definition' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { name: 'Flickr' }
        }

        extraction_definition.reload

        expect(extraction_definition.name).to eq 'Flickr'
      end

      it 'stores the user who updated it' do
        sign_out(user)
        new_user = create(:user)
        sign_in(new_user)
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { name: 'Flickr' }
        }

        expect(extraction_definition.reload.last_edited_by).to eq new_user
      end

      it 'redirects to the extraction page' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { name: 'Flickr' }
        }

        expect(response).to redirect_to(pipeline_harvest_definition_extraction_definition_path(pipeline,
                                                                                               harvest_definition, extraction_definition))
      end
    end

    context 'with invalid paramaters' do
      it 'does not update the extraction_definition' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { format: nil }
        }

        extraction_definition.reload

        expect(extraction_definition.format).not_to be_nil
      end

      it 're renders the form' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { format: nil }
        }

        expect(response.body).to include extraction_definition.name_in_database
      end
    end
  end

  describe '#clone' do
    let!(:extraction_definition)    { create(:extraction_definition, name: 'one') }
    let!(:request_one)              { create(:request, :figshare_initial_request, extraction_definition:) }
    let!(:request_two)              { create(:request, :figshare_main_request, extraction_definition:) }

    let(:pipeline_two)              { create(:pipeline) }
    let!(:harvest_definition_two)    { create(:harvest_definition, extraction_definition:, pipeline:) }

    context 'when the clone is successful' do
      it 'redirects to the Extraction Definition page' do
        post clone_pipeline_harvest_definition_extraction_definition_path(pipeline_two, harvest_definition_two, extraction_definition), params: {
          extraction_definition: {
            name: 'copy'
          }
        }
  
        expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_path(pipeline_two, harvest_definition_two, ExtractionDefinition.last)
      end

      it 'displays an appropriate message' do
        post clone_pipeline_harvest_definition_extraction_definition_path(pipeline_two, harvest_definition_two, extraction_definition), params: {
          extraction_definition: {
            name: 'copy'
          }
        }

        follow_redirect!
        
        expect(response.body).to include('Extraction Definition cloned successfully')
      end
    end

    context 'when the clone fails' do
      it 'redirects to the pipeline page' do
        post clone_pipeline_harvest_definition_extraction_definition_path(pipeline_two, harvest_definition_two, extraction_definition), params: {
          extraction_definition: {
            name: extraction_definition.name
          }
        }
  
        expect(response).to redirect_to pipeline_path(pipeline_two)
      end

      it 'displays an appropriate message' do
        post clone_pipeline_harvest_definition_extraction_definition_path(pipeline_two, harvest_definition_two, extraction_definition), params: {
          extraction_definition: {
            name: extraction_definition.name
          }
        }

        follow_redirect!
        
        expect(response.body).to include('Extraction Definition clone failed. Please confirm that your Extraction Definition name is unique and then try again.')
      end
    end
  end

  describe '#destroy' do
    let!(:request_one)              { create(:request, :figshare_initial_request, extraction_definition:) }
    let!(:request_two)              { create(:request, :figshare_main_request, extraction_definition:) }

    context 'when the deletion is successful' do
      it 'destroys the Extraction Definition' do
        expect do
          delete pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)
        end.to change(ExtractionDefinition, :count).by(-1)
      end

      it 'redirects to the pipeline path' do
        delete pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)
  
        expect(response).to redirect_to(pipeline_path(pipeline))
      end
  
      it 'displays an appropriate message' do
        delete pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)

        follow_redirect!

        expect(response.body).to include('Extraction Definition deleted successfully')
      end
    end

    context 'when the deletion is unsuccessful' do
      before do
        allow_any_instance_of(ExtractionDefinition).to receive(:destroy).and_return(false)
      end

      it 'does not destroy the Extraction Definition' do
        expect do
          delete pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)
        end.to change(ExtractionDefinition, :count).by(0)
      end

      it 'redirects to the Extraction Definition path' do
        delete pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)
  
        expect(response).to redirect_to(pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition))
      end

      it 'displays an appropriate message' do
        delete pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)

        follow_redirect!

        expect(response.body).to include('There was an issue deleting your Extraction Definition')
      end
    end
  end
end
