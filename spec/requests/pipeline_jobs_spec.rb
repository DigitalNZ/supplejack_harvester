# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PipelineJobs' do
  let(:user)         { create(:user) }
  let(:pipeline)     { create(:pipeline) }
  let(:destination)  { create(:destination) }
  let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }

  let!(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'completed', transformation_status: 'running', transformation_workers_queued: 1, transformation_workers_completed: 1, load_status: 'running', load_workers_queued: 1, load_workers_completed: 1, delete_status: 'running', delete_workers_queued: 0, delete_workers_completed: 0) }

  before do
    sign_in(user)
  end

  describe 'GET /index' do
    it 'displays a list of pipeline jobs' do
      get pipeline_pipeline_jobs_path(pipeline)

      expect(response).to have_http_status :ok
    end

    # The filters used to post to the global jobs list with the pipeline as a parameter,
    # which took you off this page to be narrowed again by an id in the query.
    it 'filters back to this pipeline rather than to the global list' do
      get pipeline_pipeline_jobs_path(pipeline)

      expect(response.body).to include "action=\"#{pipeline_pipeline_jobs_path(pipeline)}\""
      expect(response.body).not_to include "action=\"#{jobs_path}\""
    end

    it 'narrows to the filters it is given, counted against the pipeline' do
      create(:pipeline_job, pipeline:, destination:, status: 'completed')

      get pipeline_pipeline_jobs_path(pipeline), params: { status: 'errored' }

      expect(response.body).to include '0 of 2 jobs match'
    end

    it 'leaves the jobs of other pipelines out of it' do
      other = create(:pipeline, name: 'Somewhere else')
      create(:pipeline_job, pipeline: other, destination:)

      get pipeline_pipeline_jobs_path(pipeline)

      expect(response.body).not_to include 'Somewhere else'
    end
  end

  describe 'GET /show' do
    it "links to a pre-processing block's transformed data" do
      preprocess_definition = create(:harvest_definition, :preprocess, pipeline:, position: 0)
      preprocess_job = create(:harvest_job, harvest_definition: preprocess_definition, pipeline_job:)
      create(:harvest_report, pipeline_job:, harvest_job: preprocess_job, kind: 'preprocess')

      get pipeline_pipeline_job_path(pipeline, pipeline_job)

      expect(response.body).to include 'View pre-processed data'
      expect(response.body).to include pipeline_harvest_definition_preprocess_output_path(
        pipeline, preprocess_definition, pipeline_job
      )
    end

    # Every other kind loads its records to the destination, so there is nothing on
    # disk to link to.
    it 'does not offer transformed data for a harvest block' do
      get pipeline_pipeline_job_path(pipeline, pipeline_job)

      expect(response.body).to include 'View extracted data'
      expect(response.body).not_to include 'View pre-processed data'
    end

    # What the run was told to do with each block, which the page carried nothing of
    # before: the job-wide fields it used to show were the ones the Run modal stopped
    # setting when the settings became per block.
    #
    # The page draws them as the rows of the Run modal that asked for them, disabled, so
    # the assertions read the fields rather than the text of a table.
    describe 'the blocks' do
      let(:harvest) { create(:harvest_definition, kind: 'harvest', position: 1, source_id: 'main', pipeline:) }
      let(:skipped) { create(:harvest_definition, kind: 'harvest', position: 2, source_id: 'skipped', pipeline:) }

      # The pipeline already carries the block the reports above are about, at position 0.
      # A chain block left out of the settings leaves the one after it with no input, so
      # every case here starts from that one running.
      def settings(overrides)
        { harvest_definition.id.to_s => { 'run' => true, 'input' => 'fresh' } }.merge(overrides)
      end

      # The row a block's tickbox sits in, which holds its input and its page limit too.
      def block_row(definition)
        response.parsed_body.at_css("#job-block-#{definition.id}-run").ancestors('.row').first
      end

      def ran?(definition)
        response.parsed_body.at_css("#job-block-#{definition.id}-run").attr('checked').present?
      end

      def input_of(definition)
        block_row(definition).at_css('select option').text
      end

      def pages_of(definition)
        block_row(definition).at_css('input[type="number"]')['value']
      end

      it 'says what fed each block and how much of it was asked for' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: settings(harvest.id.to_s => { 'run' => true,
                                                                                  'input' => 'fresh',
                                                                                  'pages' => 5 }))

        get pipeline_pipeline_job_path(pipeline, job)

        expect(ran?(harvest)).to be true
        expect(input_of(harvest)).to eq 'Output of previous block'
        expect(pages_of(harvest)).to eq '5'
      end

      # No limit was asked for, and an empty field reads as every page against the
      # placeholder - the same way it does in the modal.
      it 'leaves the page limit empty when every page was asked for' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: settings(harvest.id.to_s => { 'run' => true,
                                                                                  'input' => 'fresh' }))

        get pipeline_pipeline_job_path(pipeline, job)

        expect(pages_of(harvest)).to be_blank
      end

      # A run is as much what it was told to leave alone as what it was told to do, so an
      # unticked block keeps its row - its box unticked, and with no input or page count
      # left to report.
      it 'lists a block that did not run, unticked' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: settings(
                                      harvest.id.to_s => { 'run' => true, 'input' => 'fresh' },
                                      skipped.id.to_s => { 'run' => false, 'input' => 'fresh' }
                                    ))

        get pipeline_pipeline_job_path(pipeline, job)

        expect(ran?(skipped)).to be false
        expect(input_of(skipped)).to eq '–'
        expect(block_row(skipped).at_css('input[type="number"]')['placeholder']).to be_nil
      end

      it 'links a block that reused an extraction to the extraction it reused' do
        extraction_definition = create(:extraction_definition, pipeline:, harvest_definitions: [harvest])
        extraction_job = create(:extraction_job, extraction_definition:)
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: settings(
                                      harvest.id.to_s => { 'run' => true,
                                                           'input' => "extraction_job:#{extraction_job.id}" }
                                    ))

        get pipeline_pipeline_job_path(pipeline, job)

        expect(input_of(harvest)).to eq extraction_job.name
        expect(block_row(harvest).at_css('a')['href']).to include "extraction_jobs/#{extraction_job.id}"
      end

      # Bootstrap switches off pointer events on a .btn inside a disabled fieldset, which
      # is what the settings above are wrapped in - the link has to be drawn as something
      # else to survive it.
      it 'leaves that link clickable inside the disabled fieldset' do
        extraction_definition = create(:extraction_definition, pipeline:, harvest_definitions: [harvest])
        extraction_job = create(:extraction_job, extraction_definition:)
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: settings(
                                      harvest.id.to_s => { 'run' => true,
                                                           'input' => "extraction_job:#{extraction_job.id}" }
                                    ))

        get pipeline_pipeline_job_path(pipeline, job)

        expect(block_row(harvest).at_css('a')['class']).not_to include 'btn'
      end

      # A purged extraction leaves the words without the link rather than a link that
      # goes nowhere.
      it 'says so when the data a block was pointed at has gone' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: settings(harvest.id.to_s => {
                                                               'run' => true,
                                                               'input' => 'extraction_job:999999'
                                                             }))

        get pipeline_pipeline_job_path(pipeline, job)

        expect(input_of(harvest)).to eq 'No longer available'
        expect(block_row(harvest).at_css('a')).to be_nil
      end

      # Nearly every run predates block_settings, and everything the API and automation
      # paths create still posts the flat fields - RunConfiguration rebuilds the rest.
      it 'describes a run that posted none of it, from the fields it did post' do
        job = create(:pipeline_job, pipeline:, destination:, page_type: :set_number, pages: 3,
                                    harvest_definitions_to_run: [harvest_definition.id.to_s, harvest.id.to_s])
        job.update_column(:block_settings, {})

        get pipeline_pipeline_job_path(pipeline, job)

        expect(input_of(harvest_definition)).to eq 'Fresh extraction'
        expect(pages_of(harvest_definition)).to eq '3'
      end
    end

    # The settings are read back in the shape they were asked for, but nothing on this
    # page submits anywhere: one disabled fieldset, and no form around it.
    describe 'the job settings' do
      it 'draws them as the disabled fields of the form that asked for them' do
        get pipeline_pipeline_job_path(pipeline, pipeline_job)

        details = response.parsed_body.at_css('fieldset[disabled]')

        expect(details).to be_present
        expect(details.ancestors('form')).to be_empty
        expect(details.at_css('#job-destination option').text).to eq destination.name
      end

      it 'answers each setting the way the form that asks for it does' do
        job = create(:pipeline_job, pipeline:, destination:, delete_previous_records: true,
                                    run_enrichment_concurrently: false)

        get pipeline_pipeline_job_path(pipeline, job)

        page = response.parsed_body

        expect(page.at_css('#job-delete-previous-records option').text).to eq 'Yes'
        expect(page.at_css('#job-run-enrichment-concurrently option').text).to eq 'No'
      end
    end
  end

  describe 'GET /harvest_jobs/:harvest_job_id/errors' do
    it 'displays grouped errors for extraction, transformation and load' do
      extraction_summary = create(:job_completion_summary,
                                  job_id: harvest_job.extraction_job_id,
                                  process_type: :extraction,
                                  job_type: 'ExtractionJob')
      transformation_summary = create(:job_completion_summary,
                                      job_id: harvest_job.id,
                                      process_type: :transformation,
                                      job_type: 'TransformationJob')

      create(:job_error, job_completion_summary: extraction_summary, job_id: harvest_job.extraction_job_id,
                         job_type: 'ExtractionJob', origin: 'ExtractionWorker',
                         message: "Extraction failure for #{harvest_job.id}")
      create(:job_error, job_completion_summary: extraction_summary, job_id: harvest_job.extraction_job_id,
                         job_type: 'ExtractionJob', origin: 'LoadWorker',
                         message: "Load failure for #{harvest_job.id}")
      create(:job_error, job_completion_summary: transformation_summary, job_id: harvest_job.id,
                         job_type: 'TransformationJob', process_type: :transformation,
                         origin: 'TransformationWorker',
                         message: "Transformation failure for #{harvest_job.id}")

      get pipeline_pipeline_job_harvest_job_errors_path(pipeline, pipeline_job, harvest_job)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Harvest Job Error Details')
      expect(response.body).to include('Extraction')
      expect(response.body).to include('Transformation')
      expect(response.body).to include('Load')
      expect(response.body).to include("Extraction failure for #{harvest_job.id}")
      expect(response.body).to include("Load failure for #{harvest_job.id}")
      expect(response.body).to include("Transformation failure for #{harvest_job.id}")
      expect(response.body).to include("href=\"#{pipeline_path(pipeline)}\"")
      expect(response.body).to include("href=\"#{pipeline_pipeline_job_path(pipeline, pipeline_job)}\"")
    end
  end

  describe 'POST /create' do
    context 'with per-block run settings' do
      let!(:preprocess) { create(:harvest_definition, :preprocess, pipeline:, position: 0) }
      let!(:harvest)    { create(:harvest_definition, pipeline:, position: 1) }
      let(:extraction_job) { create(:extraction_job, extraction_definition: harvest.extraction_definition) }

      # harvest_definition is the pipeline's other position 0 block (created by the
      # outer harvest_report), so it has to run too or the chain has a hole in it and
      # nothing is created - which would leave PipelineJob.last pointing at the outer
      # job and quietly pass. Hence the count assertion.
      it 'stores a page limit per block' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id,
              block_settings: {
                harvest_definition.id.to_s => { run: '1', input: 'fresh', pages: '' },
                preprocess.id.to_s => { run: '1', input: 'fresh', pages: '5' },
                harvest.id.to_s => { run: '1', input: 'fresh', pages: '' }
              }
            }
          }
        end.to change(PipelineJob, :count).by(1)

        job = PipelineJob.last

        expect(job.pages_for(preprocess)).to eq 5
        expect(job.pages_for(harvest)).to be_nil
      end

      it 'stores what runs and what feeds each block' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id,
            block_settings: {
              preprocess.id.to_s => { run: '0', input: 'fresh' },
              harvest.id.to_s => { run: '1', input: "extraction_job:#{extraction_job.id}" }
            }
          }
        }

        job = PipelineJob.last

        expect(job.harvest_definitions_to_run).to eq [harvest.id.to_s]
        expect(job.existing_extraction_job_for(harvest)).to eq extraction_job
      end

      it 'rejects a run whose skipped block leaves the next one with no input' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id,
              block_settings: {
                preprocess.id.to_s => { run: '0', input: 'fresh' },
                harvest.id.to_s => { run: '1', input: 'fresh' }
              }
            }
          }
        end.not_to change(PipelineJob, :count)

        follow_redirect!
        expect(response.body).to include 'There was an issue creating your pipeline job'
      end
    end

    context 'with valid parameters' do
      it 'creates a new PipelineJob' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id
            }
          }
        end.to change(PipelineJob, :count).by(1)
      end

      it 'queues a PipelineWorker' do
        expect(PipelineWorker).to receive(:perform_async)

        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }
      end

      it 'redirects to the Pipeline Jobs table' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }

        expect(response).to redirect_to(pipeline_pipeline_jobs_path(pipeline))
      end

      it 'displays an appropriate message' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }

        follow_redirect!
        expect(response.body).to include 'Pipeline job created successfully'
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new PipelineJob' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: nil
            }
          }
        end.not_to change(PipelineJob, :count)
      end

      it 'does not queue a PipelineWorker' do
        expect(PipelineWorker).not_to receive(:perform_async)

        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: nil
          }
        }
      end

      it 'redirects to the Pipeline Jobs table' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: nil
          }
        }

        expect(response).to redirect_to(pipeline_pipeline_jobs_path(pipeline))
      end

      it 'displays an appropriate message' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: nil
          }
        }

        follow_redirect!
        expect(response.body).to include 'There was an issue creating your pipeline job'
      end
    end
  end

  describe 'POST /cancel' do
    let!(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
    let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
    let!(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }

    context 'when the cancellation is successful' do
      it 'cancels the pipeline and harvest extraction_jobs' do
        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false
        harvest_job.extraction_job.running!

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to be true
        expect(harvest_job.cancelled?).to be true
        expect(harvest_job.extraction_job.cancelled?).to be true
      end

      it 'does not cancel extraction jobs that have allready completed' do
        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to be true
        expect(harvest_job.cancelled?).to be true
        expect(harvest_job.extraction_job.cancelled?).to be false
      end

      it 'displays an appropriate message' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        follow_redirect!
        expect(response.body).to include 'Pipeline job cancelled successfully'
      end

      it 'redirects to the pipeline jobs table' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        expect(response).to redirect_to pipeline_pipeline_jobs_path(pipeline)
      end
    end

    context 'when the cancellation is not successful' do
      before do
        allow_any_instance_of(PipelineJob).to receive(:cancelled!).and_return(false)
      end

      it 'does not cancel the harvest extraction jobs' do
        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false
        expect(harvest_job.extraction_job.cancelled?).to be false
      end

      it 'displays an appropriate message' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        follow_redirect!
        expect(response.body).to include 'There was an issue cancelling your pipeline job'
      end

      it 'redirects to the pipeline jobs table' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        expect(response).to redirect_to pipeline_pipeline_jobs_path(pipeline)
      end
    end
  end
end
