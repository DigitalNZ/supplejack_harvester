# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationStep do
  let(:user) { create(:user) }
  let(:automation_template) { create(:automation_template) }
  let(:automation) { create(:automation, automation_template: automation_template) }
  let(:pipeline) { create(:pipeline) }
  subject { create(:automation_step, automation: automation, launched_by: user, pipeline: pipeline) }

  it { is_expected.to belong_to(:automation) }
  it { is_expected.to belong_to(:pipeline).optional }
  it { is_expected.to belong_to(:launched_by).optional }
  it { is_expected.to have_one(:pipeline_job).dependent(:destroy) }
  it { is_expected.to have_one(:api_response_report).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

  context 'when step_type is pipeline' do
    subject { build(:automation_step, step_type: 'pipeline') }
    
    it { is_expected.to validate_presence_of(:pipeline_id) }
  end

  context 'when step_type is api_call' do
    subject { build(:automation_step, step_type: 'api_call') }
    
    it { is_expected.to validate_presence_of(:api_url) }
    it { is_expected.to validate_presence_of(:api_method) }
  end

  describe '#harvest_definitions' do
    it 'returns harvest definitions from IDs' do
      pipeline = subject.pipeline
      harvest_definition = create(:harvest_definition, pipeline: pipeline)
      
      subject.harvest_definition_ids = [harvest_definition.id]
      subject.save

      expect(subject.harvest_definitions).to include(harvest_definition)
    end

    it 'returns empty array when pipeline is nil' do
      step = build(:automation_step, :api_call, pipeline: nil)
      expect(step.harvest_definitions).to eq([])
    end

    it 'returns all harvest definitions when harvest_definition_ids is blank' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline: pipeline)
      step = create(:automation_step, pipeline: pipeline, harvest_definition_ids: [])
      
      expect(step.harvest_definitions).to include(harvest_definition)
    end
  end

  describe '#display_name' do
    it 'returns a formatted name with position and pipeline name for pipeline steps' do
      step = create(:automation_step, step_type: 'pipeline')
      expect(step.display_name).to eq("#{step.position + 1}. #{step.pipeline.name}")
    end

    it 'returns a formatted name with api method and url for api call steps' do
      step = create(:automation_step, :api_call)
      expect(step.display_name).to eq("#{step.position + 1}. API Call: GET https://example.com/api")
    end
  end

  describe '#status' do
    context 'when step is pipeline type' do
      subject { create(:automation_step, step_type: 'pipeline') }
      
      context 'when no pipeline job exists' do
        it 'returns not_started' do
          expect(subject.status).to eq('not_started')
        end
      end

      context 'when pipeline job exists but no harvest reports' do
        let(:pipeline_job) { create(:pipeline_job, automation_step: subject, pipeline: subject.pipeline) }

        before do
          subject.pipeline_job = pipeline_job
        end

        it 'returns not_started' do
          expect(subject.status).to eq('not_started')
        end
      end

      context 'when harvest reports exist' do
        let(:pipeline_job) { create(:pipeline_job, automation_step: subject, pipeline: subject.pipeline) }
        let(:harvest_definition) { create(:harvest_definition, pipeline: subject.pipeline) }
        let(:extraction_job) { create(:extraction_job) }
        let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }
        
        before do
          subject.pipeline_job = pipeline_job
        end

        it 'returns completed when all reports are completed' do
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                extraction_status: 'completed', 
                transformation_status: 'completed', 
                load_status: 'completed',
                delete_status: 'completed')
          expect(subject.status).to eq('completed')
        end

        it 'returns running when any report is running' do
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                extraction_status: 'running', 
                transformation_status: 'completed', 
                load_status: 'completed',
                delete_status: 'completed')
          expect(subject.status).to eq('running')
        end

        it 'returns failed when any report is errored' do
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                extraction_status: 'errored', 
                transformation_status: 'completed', 
                load_status: 'completed',
                delete_status: 'completed')
          expect(subject.status).to eq('errored')
        end
      end
    end
    
    context 'when step is api_call type' do
      subject { create(:automation_step, :api_call) }
      
      it 'returns not_started when no api_response_report exists' do
        expect(subject.status).to eq('not_started')
      end
      
      it 'returns the status from api_response_report' do
        create(:api_response_report, automation_step: subject, status: 'completed')
        expect(subject.status).to eq('completed')
        
        create(:api_response_report, automation_step: subject, status: 'errored')
        expect(subject.status).to eq('errored')
        
        create(:api_response_report, automation_step: subject, status: 'queued')
        expect(subject.status).to eq('queued')
      end
    end
  end

  describe '#next_step' do
    it 'returns the next step in the sequence' do
      step1 = create(:automation_step, automation: automation, position: 0, launched_by: user, pipeline: pipeline)
      step2 = create(:automation_step, automation: automation, position: 1, launched_by: user, pipeline: pipeline)
      step3 = create(:automation_step, automation: automation, position: 2, launched_by: user, pipeline: pipeline)

      expect(step1.next_step).to eq(step2)
      expect(step2.next_step).to eq(step3)
      expect(step3.next_step).to be_nil
    end
  end

  describe '#destination' do
    it 'returns the automation destination' do
      expect(subject.destination).to eq(subject.automation.destination)
    end
  end

  describe '#destination_id' do
    it 'returns the automation destination ID' do
      expect(subject.destination_id).to eq(subject.automation.destination.id)
    end
  end
  
  describe '#execute_api_call' do
    let(:api_step) { create(:automation_step, :api_call) }
    
    it 'creates a queued api_response_report if none exists' do
      expect { api_step.execute_api_call }.to change { ApiResponseReport.count }.by(1)
      
      report = api_step.reload.api_response_report
      expect(report.status).to eq('queued')
    end
    
    it 'does not create a new report if one already exists' do
      api_step.create_api_response_report(status: 'queued')
      
      expect { api_step.execute_api_call }.not_to change { ApiResponseReport.count }
    end
    
    it 'enqueues an ApiCallWorker job' do
      expect(ApiCallWorker).to receive(:perform_in).with(5.seconds, api_step.id)
      api_step.execute_api_call
    end
  end

  describe 'pre-extraction step features' do
    let(:extraction_definition) { create(:extraction_definition, pre_extraction: true) }

    context 'when step_type is pre_extraction' do
      subject { build(:automation_step, step_type: 'pre_extraction', extraction_definition:, pipeline: nil) }

      it { is_expected.to validate_presence_of(:extraction_definition_id) }
    end

    describe '#display_name for pre_extraction step' do
      it 'returns a formatted name with extraction definition name' do
        step = create(:automation_step, :pre_extraction, extraction_definition:)
        expect(step.display_name).to include('Pre-Extraction')
        expect(step.display_name).to include(extraction_definition.name)
      end
    end

    describe '#pre_extraction_status' do
      subject { create(:automation_step, :pre_extraction, extraction_definition:) }

      it 'returns not_started when no pre_extraction_job exists' do
        expect(subject.pre_extraction_status).to eq('not_started')
      end

      it 'returns the job status when pre_extraction_job exists' do
        job = create(:extraction_job, status: 'running')
        subject.update(pre_extraction_job: job)

        expect(subject.pre_extraction_status).to eq('running')
      end
    end

    describe '#execute_pre_extraction' do
      subject { create(:automation_step, :pre_extraction, extraction_definition:) }

      it 'creates an extraction job' do
        expect { subject.execute_pre_extraction }.to change { ExtractionJob.count }.by(1)
      end

      it 'sets is_pre_extraction flag on the job' do
        subject.execute_pre_extraction
        subject.reload

        expect(subject.pre_extraction_job.is_pre_extraction).to be true
      end

      it 'links the extraction job to the step' do
        subject.execute_pre_extraction
        subject.reload

        expect(subject.pre_extraction_job).to be_present
        expect(subject.pre_extraction_job.extraction_definition).to eq extraction_definition
      end

      it 'does not create a new job if one already exists' do
        subject.execute_pre_extraction
        
        expect { subject.execute_pre_extraction }.not_to change { ExtractionJob.count }
      end
    end

    describe '#find_previous_pre_extraction_job_id' do
      let(:automation) { create(:automation) }
      let(:ed1) { create(:extraction_definition, pre_extraction: true) }
      let(:ed2) { create(:extraction_definition, pre_extraction: true) }

      it 'returns nil when no previous pre-extraction step exists' do
        step = create(:automation_step, :pre_extraction, automation:, position: 0, extraction_definition: ed1)
        expect(step.find_previous_pre_extraction_job_id).to be_nil
      end

      it 'returns the pre_extraction_job_id from the previous pre-extraction step' do
        step1 = create(:automation_step, :pre_extraction, automation:, position: 0, extraction_definition: ed1)
        step1.execute_pre_extraction
        step1.reload

        step2 = create(:automation_step, :pre_extraction, automation:, position: 1, extraction_definition: ed2)

        expect(step2.find_previous_pre_extraction_job_id).to eq step1.pre_extraction_job_id
      end
    end
  end
end