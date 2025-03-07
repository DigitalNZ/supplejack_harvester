# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationStep do
  let(:user) { create(:user) }
  let(:automation_template) { create(:automation_template) }
  let(:automation) { create(:automation, automation_template: automation_template) }
  let(:pipeline) { create(:pipeline) }
  subject { create(:automation_step, automation: automation, launched_by: user, pipeline: pipeline) }

  it { is_expected.to belong_to(:automation) }
  it { is_expected.to belong_to(:pipeline) }
  it { is_expected.to belong_to(:launched_by).optional }
  it { is_expected.to have_one(:pipeline_job).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

  describe '#harvest_definitions' do
    it 'returns harvest definitions from IDs' do
      pipeline = subject.pipeline
      harvest_definition = create(:harvest_definition, pipeline: pipeline)
      
      subject.harvest_definition_ids = [harvest_definition.id]
      subject.save

      expect(subject.harvest_definitions).to include(harvest_definition)
    end
  end

  describe '#display_name' do
    it 'returns a formatted name with position and pipeline name' do
      expect(subject.display_name).to eq("#{subject.position + 1}. #{subject.pipeline.name}")
    end
  end

  describe '#status' do
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
      let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
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
end 