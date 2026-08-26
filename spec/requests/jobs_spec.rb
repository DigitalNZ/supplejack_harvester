# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Jobs' do
  let(:user)              { create(:user, username: 'tim') }
  let(:someone_else)      { create(:user, username: 'ana') }
  let(:pipeline)          { create(:pipeline, name: 'Figshare') }
  let(:other_pipeline)    { create(:pipeline, name: 'Europeana') }
  let(:destination)       { create(:destination, name: 'Production') }
  let(:other_destination) { create(:destination, name: 'Staging') }

  # The listed jobs, rather than the rendered table: a row only appears for a job whose
  # harvest_definitions_to_run line up with its reports, which says nothing about
  # whether the filtering worked.
  def listed_jobs
    assigns(:pipeline_jobs)
  end

  before { sign_in(user) }

  describe 'GET /index' do
    it 'lists the jobs' do
      job = create(:pipeline_job, pipeline:, destination:)

      get jobs_path

      expect(response).to have_http_status :ok
      expect(listed_jobs).to contain_exactly job
    end

    describe 'filtering by pipeline' do
      it "keeps only that pipeline's jobs" do
        job = create(:pipeline_job, pipeline:, destination:)
        create(:pipeline_job, pipeline: other_pipeline, destination:)

        get jobs_path(pipeline_id: pipeline.id)

        expect(listed_jobs).to contain_exactly job
      end

      # The filter used to be skipped whenever the first job in the table had no
      # pipeline_id, which a single orphaned run was enough to trigger: the guard read
      # the data to work out whether the column existed.
      it 'still filters when a job without a pipeline is in the table' do
        orphan = build(:pipeline_job, pipeline: nil, destination:)
        orphan.save!(validate: false)
        job = create(:pipeline_job, pipeline:, destination:)
        create(:pipeline_job, pipeline: other_pipeline, destination:)

        get jobs_path(pipeline_id: pipeline.id)

        expect(listed_jobs).to contain_exactly job
      end
    end

    describe 'filtering by status' do
      let!(:completed) { create(:pipeline_job, pipeline:, destination:, status: 'completed') }
      let!(:errored)   { create(:pipeline_job, pipeline: other_pipeline, destination:, status: 'errored') }

      it 'keeps only jobs in that status' do
        get jobs_path(status: 'Completed')

        expect(listed_jobs).to contain_exactly completed
      end

      it 'lists everything for All' do
        get jobs_path(status: 'All')

        expect(listed_jobs).to contain_exactly completed, errored
      end

      # A value the enum does not know used to compile to `status IS NULL`, quietly
      # listing the jobs that have no status at all instead.
      it 'ignores a status no job can be in' do
        no_status = build(:pipeline_job, pipeline:, destination:, status: nil)
        no_status.save!(validate: false)

        get jobs_path(status: 'Nonsense')

        expect(response).to have_http_status :ok
        expect(listed_jobs).to contain_exactly completed, errored, no_status
      end
    end

    describe 'filtering by destination' do
      it 'keeps only jobs sent to that destination' do
        job = create(:pipeline_job, pipeline:, destination:)
        create(:pipeline_job, pipeline: other_pipeline, destination: other_destination)

        get jobs_path(destination: 'Production')

        expect(listed_jobs).to contain_exactly job
      end

      it 'ignores a destination that does not exist' do
        job = create(:pipeline_job, pipeline:, destination:)

        get jobs_path(destination: 'Gone')

        expect(response).to have_http_status :ok
        expect(listed_jobs).to contain_exactly job
      end
    end

    describe 'filtering by who ran the job' do
      # A schedule and an automation are how the table labels the jobs they ran, so they
      # are what this filter offers alongside the usernames - see job_launched_by_label.
      let(:schedule) do
        create(:schedule, destination:, automation_template: create(:automation_template, destination:))
      end
      let(:automation_step) do
        create(:automation_step, automation: create(:automation, destination:), pipeline:)
      end

      it 'keeps only the jobs that user launched' do
        job = create(:pipeline_job, pipeline:, destination:, launched_by: user)
        create(:pipeline_job, pipeline: other_pipeline, destination:, launched_by: someone_else)

        get jobs_path(run_by: 'tim')

        expect(listed_jobs).to contain_exactly job
      end

      it 'keeps only the jobs an automation ran' do
        job = create(:pipeline_job, pipeline:, destination:, automation_step:, launched_by: user)
        create(:pipeline_job, pipeline:, destination:, launched_by: user)
        create(:pipeline_job, pipeline:, destination:, schedule:, launched_by: user)

        get jobs_path(run_by: 'Automation')

        expect(listed_jobs).to contain_exactly job
      end

      # Selecting Schedule used to look for a user of that name, find none, and leave the
      # list as it was - so it appeared to match everything, automations included.
      it 'keeps only the jobs a schedule ran' do
        job = create(:pipeline_job, pipeline:, destination:, schedule:, launched_by: user)
        create(:pipeline_job, pipeline:, destination:, automation_step:, launched_by: user)
        create(:pipeline_job, pipeline:, destination:, launched_by: user)

        get jobs_path(run_by: 'Schedule')

        expect(listed_jobs).to contain_exactly job
      end

      # The name on such a job is whoever set the schedule or the automation up, and the
      # table does not label it with them, so this filter does not either.
      it 'leaves scheduled and automated jobs out of a username' do
        job = create(:pipeline_job, pipeline:, destination:, launched_by: user)
        create(:pipeline_job, pipeline:, destination:, schedule:, launched_by: user)
        create(:pipeline_job, pipeline:, destination:, automation_step:, launched_by: user)

        get jobs_path(run_by: 'tim')

        expect(listed_jobs).to contain_exactly job
      end

      it 'ignores a username nobody has' do
        job = create(:pipeline_job, pipeline:, destination:, launched_by: user)

        get jobs_path(run_by: 'nobody')

        expect(response).to have_http_status :ok
        expect(listed_jobs).to contain_exactly job
      end
    end

    describe 'filtering by the tags on the pipeline' do
      let(:museum)   { create(:tag, name: 'Museum') }
      let(:priority) { create(:tag, name: 'High priority') }

      let(:both_tags)   { create(:pipeline, name: 'Auckland Museum').tap { it.tags = [museum, priority] } }
      let(:museum_only) { create(:pipeline, name: 'Te Papa').tap { it.tags = [museum] } }

      it 'lists the jobs of pipelines carrying the tag' do
        wanted = create(:pipeline_job, pipeline: museum_only, destination:)
        create(:pipeline_job, pipeline: other_pipeline, destination:)

        get jobs_path(tags: ['museum'])

        expect(listed_jobs).to contain_exactly wanted
      end

      # A job has no tags of its own, and every tag narrows the list.
      it 'lists only the jobs of pipelines carrying all of the tags' do
        wanted = create(:pipeline_job, pipeline: both_tags, destination:)
        create(:pipeline_job, pipeline: museum_only, destination:)

        get jobs_path(tags: %w[museum high-priority])

        expect(listed_jobs).to contain_exactly wanted
      end

      it 'combines with the other filters' do
        wanted = create(:pipeline_job, pipeline: both_tags, destination:, status: 'completed')
        create(:pipeline_job, pipeline: both_tags, destination:, status: 'errored')
        create(:pipeline_job, pipeline: museum_only, destination:, status: 'completed')

        get jobs_path(tags: %w[museum high-priority], status: 'Completed')

        expect(listed_jobs).to contain_exactly wanted
      end

      it 'lists nothing for a tag no pipeline carries' do
        create(:pipeline_job, pipeline: museum_only, destination:)

        get jobs_path(tags: ['unknown'])

        expect(listed_jobs).to be_empty
        expect(response.body).to include 'No jobs belong to a pipeline carrying all of those tags'
      end
    end

    it 'combines filters with AND' do
      wanted = create(:pipeline_job, pipeline:, destination:, status: 'completed', launched_by: user)
      create(:pipeline_job, pipeline:, destination:, status: 'errored', launched_by: user)
      create(:pipeline_job, pipeline:, destination:, status: 'completed', launched_by: someone_else)
      create(:pipeline_job, pipeline:, destination: other_destination, status: 'completed', launched_by: user)

      get jobs_path(status: 'Completed', run_by: 'tim', destination: 'Production')

      expect(listed_jobs).to contain_exactly wanted
    end

    it 'filters across the whole set rather than within the current page' do
      create_list(:pipeline_job, 25, pipeline:, destination:, status: 'errored')
      wanted = create_list(:pipeline_job, 3, pipeline: other_pipeline, destination:, status: 'completed')

      get jobs_path(status: 'Completed')

      expect(listed_jobs).to match_array wanted
      expect(listed_jobs.total_count).to eq 3
    end
  end

  describe 'GET /index for a single extraction definition' do
    # The extraction jobs list shares the filtering, and its route always carries a
    # pipeline_id even though extraction_jobs has no such column.
    it 'ignores filters that do not apply to extraction jobs' do
      harvest_definition = create(:harvest_definition, pipeline:)
      extraction_definition = create(:extraction_definition, pipeline:)
      harvest_definition.update(extraction_definition:)
      extraction_job = create(:extraction_job, extraction_definition:)

      get pipeline_harvest_definition_extraction_definition_extraction_jobs_path(
        pipeline, harvest_definition, extraction_definition,
        destination: 'Production', run_by: 'tim', tags: ['museum']
      )

      expect(response).to have_http_status :ok
      expect(assigns(:extraction_jobs)).to contain_exactly extraction_job
    end

    # Run by Schedule and Automation look at columns of their own, which that table has
    # no more than it has the rest of them.
    it 'ignores who ran it when the column is not there to ask' do
      harvest_definition = create(:harvest_definition, pipeline:)
      extraction_definition = create(:extraction_definition, pipeline:)
      harvest_definition.update(extraction_definition:)
      extraction_job = create(:extraction_job, extraction_definition:)

      %w[Schedule Automation].each do |run_by|
        get pipeline_harvest_definition_extraction_definition_extraction_jobs_path(
          pipeline, harvest_definition, extraction_definition, run_by:
        )

        expect(response).to have_http_status :ok
        expect(assigns(:extraction_jobs)).to contain_exactly extraction_job
      end
    end
  end
end
