# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pipelines' do
  let(:user) { create(:user) }
  let!(:pipeline) { create(:pipeline, name: 'DigitalNZ Production') }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }

  before do
    sign_in(user)
  end

  describe 'GET /index' do
    it 'displays a list of pipelines' do
      get pipelines_path

      expect(response).to have_http_status :ok
      expect(response.body).to include CGI.escapeHTML(pipeline.name)
    end

    context 'when asked for the queued runs' do
      let(:destination) { create(:destination) }

      it 'lists a pipeline whose run has not begun' do
        create(:pipeline_job, pipeline:, destination:, status: 'queued')

        get pipelines_path(status: 'queued')

        expect(response.body).to include CGI.escapeHTML(pipeline.name)
      end

      # PipelineWorker refuses to start a run whose blocks cannot run, which leaves it over
      # with nothing to report. Nothing about it is still coming.
      it 'leaves out one whose run is over without having reported anything' do
        create(:pipeline_job, pipeline:, destination:, status: 'errored')

        get pipelines_path(status: 'queued')

        expect(response.body).not_to include CGI.escapeHTML(pipeline.name)
      end
    end
  end

  describe 'POST /create' do
    context 'with valid attributes' do
      it 'creates a new pipeline' do
        expect do
          post pipelines_path, params: {
            pipeline: attributes_for(:pipeline)
          }
        end.to change(Pipeline, :count).by(1)
      end

      it 'stores the user who created it' do
        post pipelines_path, params: {
          pipeline: attributes_for(:pipeline)
        }

        expect(Pipeline.last.last_edited_by).to eq user
      end

      it 'redirects to the created pipeline' do
        post pipelines_path, params: {
          pipeline: attributes_for(:pipeline)
        }

        expect(request).to redirect_to(pipeline_path(Pipeline.last))
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new pipeline' do
        expect do
          post pipelines_path, params: {
            pipeline: {
              name: nil,
              description: nil
            }
          }
        end.not_to change(Pipeline, :count)
      end

      it 'renders the :index template' do
        post pipelines_path, params: {
          pipeline: {
            name: nil,
            description: nil
          }
        }

        expect(response.body).to include 'Pipelines'
        expect(response.body).to include 'There was an issue creating your Pipeline'
      end
    end
  end

  describe 'GET /show' do
    it 'renders a specific pipeline' do
      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include pipeline.name
    end

    it 'configures each block separately in the Run modal' do
      create(:field, transformation_definition: harvest_definition.transformation_definition)
      preprocess = create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'pre-one',
                                               transformation_definition:
                                                 harvest_definition.transformation_definition)

      get pipeline_path(pipeline)

      expect(response.body).to include CGI.escapeHTML("pipeline_job[block_settings][#{preprocess.id}][run]")
      expect(response.body).to include CGI.escapeHTML("pipeline_job[block_settings][#{preprocess.id}][input]")
      expect(response.body).to include CGI.escapeHTML("pipeline_job[block_settings][#{harvest_definition.id}][input]")
      expect(response.body).to include CGI.escapeHTML("pipeline_job[block_settings][#{preprocess.id}][pages]")

      # The job-wide "Transformation input" and "Pages to transform" controls are gone:
      # both are per-block choices now.
      expect(response.body).not_to include 'Transformation input'
      expect(response.body).not_to include 'Pages to transform'
    end

    # The harvest block's card is rendered through a different route than the
    # pre-processing and enrichment ones, and a harvest sitting after a pre-processing
    # block works from its records just the same - so it has to be asked which run to
    # take them from rather than being fired off with nothing to read.
    it 'asks a harvest block placed after a pre-processing block which run to work from' do
      create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'pre-one')
      harvest_definition.update!(position: 1, source_id: 'harvest-block')

      get pipeline_path(pipeline)

      expect(response.body).to include "run-extraction-#{harvest_definition.id}"
      expect(response.body).to include 'choose which run to take them from'
    end

    it 'offers "Add Pre-processing" in the add-block dropdown before any blocks exist' do
      empty_pipeline = create(:pipeline, name: 'Empty pipeline')

      get pipeline_path(empty_pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Add Pre-processing'
    end

    it 'still offers "Add Pre-processing" once the pipeline has blocks' do
      create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'pre-one')

      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Add Pre-processing'
      # The add-preprocess modal's hidden position must append to the END of the existing
      # preprocess chain (one block at position 0 exists, so the next one goes to 1).
      expect(response.body).to match(/value="1"[^>]*name="harvest_definition\[position\]"/)
    end

    it 'offers to add a load definition to a block that has none' do
      harvest_definition.update_columns(load_definition_id: nil)

      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include '+ Add harvest load'
    end

    it 'shows the load definition of a block that has one' do
      load_definition = create(:load_definition, pipeline:, kind: 'secondary_fragment', priority: -1)
      harvest_definition.update(load_definition:)

      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include load_definition.name
      expect(response.body).not_to include '+ Add harvest load'
    end

    # The reasons live in the Run modal, in the row of the block they belong to.
    it 'says in the Run modal why a block whose definitions contradict each other cannot run' do
      harvest_definition.update(load_definition: create(:load_definition, pipeline:, kind: 'secondary_fragment'))
      create(:field, name: 'title', transformation_definition: harvest_definition.transformation_definition)

      get pipeline_path(pipeline)

      expect(response.body).to include CGI.escapeHTML(
        'Cannot run: it writes a secondary fragment, so its transformation has to set internal_identifier.'
      )
    end

    it 'says why a block is merely unfinished too, the modal being where a block is chosen' do
      create(:harvest_definition, pipeline:, kind: :enrichment, source_id: 'half-built',
                                  extraction_definition: nil, transformation_definition: nil)

      get pipeline_path(pipeline)

      expect(response.body).to include CGI.escapeHTML(
        'Cannot run: it has no extraction definition and it has no transformation definition.'
      )
    end

    # Opening it is how the reasons get read, so it must open even when nothing can run.
    it 'offers the Run modal while the pipeline has blocks, runnable or not' do
      get pipeline_path(pipeline)

      expect(response.body).to include 'run-settings'
      expect(response.body).not_to match(/<button[^>]*disabled[^>]*bs-target="#run-settings"/)
    end

    it 'refuses to start a run when no block can run, and says so' do
      get pipeline_path(pipeline)

      expect(response.body).to include 'No block in this pipeline can run yet.'
      expect(response.body).to match(/<button[^>]*disabled[^>]*>Run<\/button>/)
    end

    it 'lets a run start when a block can, even alongside one that cannot' do
      create(:field, name: 'title', transformation_definition: harvest_definition.transformation_definition)
      create(:harvest_definition, pipeline:, kind: :enrichment, source_id: 'half-built',
                                  extraction_definition: nil, transformation_definition: nil)

      get pipeline_path(pipeline)

      expect(response.body).not_to include 'No block in this pipeline can run yet.'
      expect(response.body).to match(/<button[^>]*>Run<\/button>/)
      expect(response.body).not_to match(/<button[^>]*disabled[^>]*>Run<\/button>/)
    end

    it 'has nothing to open on a pipeline with no blocks at all' do
      empty = create(:pipeline, name: 'No blocks')

      get pipeline_path(empty)

      expect(response.body).to match(/<button[^>]*disabled[^>]*bs-target="#run-settings"/)
    end

    # Sharing arises from cloning a pipeline, which points the clone's blocks at the same
    # definitions. Both blocks have to be a kind that can do this load, so they are both
    # harvests - which is also what a cloned pipeline gives you.
    it 'offers to clone a load definition shared with another block' do
      load_definition = create(:load_definition, pipeline:)
      harvest_definition.update(load_definition:)
      create(:harvest_definition, pipeline: create(:pipeline), kind: :harvest, source_id: 'cloned', load_definition:)

      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Edit shared Load'
      expect(response.body).to include CGI.escapeHTML(
        clone_pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)
      )
    end

    it 'renders the load column on enrichment and pre-processing blocks too' do
      create(:harvest_definition, pipeline:, kind: :enrichment, source_id: 'enrich-one', load_definition: nil)
      create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'pre-one',
                                  load_definition: nil)

      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include '+ Add enrichment load'
      expect(response.body).to include '+ Add pre-processing load'
    end

    it 'offers "Add Harvest" when the pipeline has blocks but no harvest yet' do
      preprocess_pipeline = create(:pipeline, name: 'Preprocess only')
      create(:harvest_definition, pipeline: preprocess_pipeline, kind: :preprocess, position: 0,
                                  source_id: 'pre-one')

      get pipeline_path(preprocess_pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Add Harvest'
    end

    it 'does not offer "Add Harvest" when the pipeline already has a harvest' do
      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      # "Add Harvest" (capital H) is the dropdown entry's exact label; the harvest block's own
      # "+ Add harvest extraction/transformation" CTAs and the "Add harvest" modal heading are
      # lowercase-h, so this assertion targets only the dropdown entry.
      expect(response.body).not_to include 'Add Harvest'
    end

    it 'renders preprocess blocks in position order, before the harvest' do
      # Build the chain through the controller (the same path the UI takes), which appends the
      # preprocess positions and keeps the harvest's position at the end of the chain - rather
      # than hand-setting positions the UI could never produce.
      harvest_definition.update!(source_id: 'harvest-block')
      post pipeline_harvest_definitions_path(pipeline), params: {
        harvest_definition: { pipeline_id: pipeline.id, source_id: 'pre-one', kind: 'preprocess', position: 0 }
      }
      post pipeline_harvest_definitions_path(pipeline), params: {
        harvest_definition: { pipeline_id: pipeline.id, source_id: 'pre-two', kind: 'preprocess', position: 1 }
      }

      get pipeline_path(pipeline)

      body = response.body
      expect(body.index('pre-one')).to be < body.index('pre-two')
      expect(body.index('pre-two')).to be < body.index('harvest-block')
    end

    it "points a pre-processing block's create-extraction-definition form at its own " \
       'harvest_definition, not the pipeline harvest' do
      preprocess = create(:harvest_definition, pipeline:, kind: :preprocess, position: 0,
                                               source_id: 'pre-one', extraction_definition: nil)

      get pipeline_path(pipeline)

      expected_action = pipeline_harvest_definition_extraction_definitions_path(pipeline, preprocess)
      wrong_action = pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition)

      # Match the exact quoted form `action="..."` attribute (not a loose substring), since the
      # harvest's own extraction/transformation *member* routes (edit/delete/jobs links, which DO
      # already exist for `harvest_definition` on this page) share the same collection path as a
      # prefix, e.g. ".../extraction_definitions/42" - a plain #include? on the bare path would
      # give a false failure there.
      expect(response.body).to include "action=\"#{CGI.escapeHTML(expected_action)}\""
      expect(response.body).not_to include "action=\"#{CGI.escapeHTML(wrong_action)}\""
    end
  end

  describe 'PATCH /update' do
    context 'with valid parameters' do
      it 'updates the content source' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: 'National Library of New Zealand' }
        }

        pipeline.reload

        expect(pipeline.name).to eq 'National Library of New Zealand'
      end

      it 'stores the user who updated it' do
        sign_out(user)
        new_user = create(:user)
        sign_in(new_user)
        patch pipeline_path(pipeline), params: {
          pipeline: { name: 'National Library of New Zealand' }
        }

        expect(pipeline.reload.last_edited_by).to eq new_user
      end

      it 'redirects to the pipeline page' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: 'National Library of New Zealand' }
        }

        expect(response).to redirect_to pipeline_path(pipeline)
      end
    end

    context 'with invalid paramaters' do
      it 'does not update the pipeline' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: nil }
        }

        pipeline.reload

        expect(pipeline.name).not_to be_nil
      end

      it 're renders the form' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: nil }
        }

        expect(response.body).to include pipeline.name_in_database
      end
    end
  end

  describe 'DELETE /destroy' do
    context 'when a pipeline is deleted successfully' do
      it 'deletes a pipeline' do
        expect do
          delete pipeline_path(pipeline)
        end.to change(Pipeline, :count).by(-1)
      end

      it 'redirects to the pipelines path' do
        delete pipeline_path(pipeline)

        expect(response).to redirect_to pipelines_path

        follow_redirect!
        expect(response.body).to include 'Pipeline deleted successfully'
      end
    end

    context 'when a pipeline fails to be deleted' do
      before do
        allow_any_instance_of(Pipeline).to receive(:destroy).and_return(false)
      end

      it 'does not delete a pipeline' do
        expect do
          delete pipeline_path(pipeline)
        end.not_to change(Pipeline, :count)
      end

      it 'redirects to the pipeline path and displays a message' do
        delete pipeline_path(pipeline)

        expect(response).to redirect_to(pipeline_path(pipeline))
        follow_redirect!
        expect(response.body).to include 'There was an issue deleting your Pipeline'
      end
    end
  end

  describe 'GET /harvest_definitions' do
    it 'returns status 200' do
      get harvest_definitions_pipeline_path(pipeline)
      expect(response).to have_http_status :ok
    end

    it 'renders the harvest definitions for a pipeline as JSON' do
      get harvest_definitions_pipeline_path(pipeline)

      expect(response.body).to eq pipeline.harvest_definitions.map(&:to_h).to_json
    end
  end

  describe 'GET /run_blocks' do
    let(:destination) { create(:destination) }
    let!(:preprocess) { create(:harvest_definition, :preprocess, pipeline:, position: 0) }
    let!(:harvest)    { create(:harvest_definition, pipeline:, position: 1) }

    def checked?(id)
      Nokogiri::HTML(response.body).at_css("##{id}")&.attr('checked').present?
    end

    it 'renders the block rows for the schedule form' do
      get pipeline_run_blocks_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include "schedule[block_settings][#{preprocess.id}][run]"
      expect(response.body).to include "schedule[block_settings][#{harvest.id}][input]"
    end

    it 'offers the most recent pre-processed data, which schedules resolve at run time' do
      get pipeline_run_blocks_path(pipeline)

      expect(response.body).to include 'preprocess_output:latest'
    end

    it "renders an existing schedule's selection" do
      # The schedule runs only the harvest, on whatever pre-processed data is most
      # recent when it fires.
      schedule = create(:schedule, pipeline:, destination:,
                                   block_settings: {
                                     harvest.id.to_s => { 'run' => true, 'input' => 'preprocess_output:latest' }
                                   })

      get pipeline_run_blocks_path(pipeline), params: { schedule_id: schedule.id }

      expect(checked?("schedule_block_#{harvest.id}_run")).to be true
      expect(checked?("schedule_block_#{preprocess.id}_run")).to be false
    end
  end

  describe '/POST clone' do

    let(:pipeline)                  { create(:pipeline) }

    let(:extraction_definition)     { create(:extraction_definition) }
    let!(:request_one)              { create(:request, :figshare_initial_request, extraction_definition:) }
    let!(:request_two)              { create(:request, :figshare_main_request, extraction_definition:) }

    let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
    let(:request)                   { create(:request, :figshare_initial_request, extraction_definition:) }
    let(:transformation_definition) do
      create(:transformation_definition, pipeline:, extraction_job:, record_selector: '$..items')
    end

    let!(:field_one) do
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition:)
    end
    let!(:field_two) do
      create(:field, name: 'source', block: "JsonPath.new('source').on(record).first", transformation_definition:)
    end

    let!(:harvest_definition)    { create(:harvest_definition, extraction_definition:, transformation_definition:, pipeline:, priority: -1) }
    
    context 'when the clone is successful' do
      it 'redirects to the new Pipeline page' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: 'copy'
          }
        }
  
        expect(response).to redirect_to pipeline_path(Pipeline.last)
      end
  
      it 'creates a new pipeline' do
        expect do
          post clone_pipeline_path(pipeline), params: {
            pipeline: {
              name: 'copy'
            }
          }
        end.to change(Pipeline, :count).by(1)
      end
  
      it 'creates new harvest definitions based on the provided pipeline' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: 'copy'
          }
        }
  
        cloned_pipeline = Pipeline.last
  
        expect(cloned_pipeline).not_to eq pipeline
  
        expect(cloned_pipeline.harvest_definitions.count).to eq pipeline.harvest_definitions.count
        expect(cloned_pipeline.harvest_definitions.first.extraction_definition).to eq pipeline.harvest_definitions.first.extraction_definition
        expect(cloned_pipeline.harvest_definitions.first.transformation_definition).to eq pipeline.harvest_definitions.first.transformation_definition
  
        expect(cloned_pipeline.harvest_definitions.first.extraction_definition.shared?).to eq true
        expect(cloned_pipeline.harvest_definitions.first.transformation_definition.shared?).to eq true
      end
  
      it 'displays a successful message' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: 'copy'
          }
        }
  
        follow_redirect!
  
        expect(response.body).to include 'Pipeline cloned successfully'
      end
    end

    context 'when the clone is not successful' do
      it 'does not create a new pipeline' do
        expect do
          post clone_pipeline_path(pipeline), params: {
            pipeline: {
              name: pipeline.name
            }
          }
        end.to change(Pipeline, :count).by(0)
      end

      it 'displays a helpful message' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: pipeline.name
          }
        }

        follow_redirect!

        expect(response.body).to include 'Pipeline clone failed. Please confirm that your Pipeline name is unique and then try again.'
      end
    end
  end
end
