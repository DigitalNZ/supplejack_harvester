# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationSummary do
  let(:user) { create(:user) }
  let(:destination) { create(:destination) }
  let(:automation_template) { create(:automation_template, destination: destination) }
  let(:pipeline) { create(:pipeline) }
  let(:automation) { create(:automation, destination: destination, automation_template: automation_template) }
  let(:step) { create(:automation_step, automation: automation, launched_by: user, pipeline: pipeline, position: 0) }
  
  subject { described_class.new(automation) }

  describe '#initialize' do
    it 'stores the automation' do
      expect(subject.instance_variable_get(:@automation)).to eq(automation)
    end
  end

  describe '#start_time' do
    it 'returns the automation created_at time' do
      expect(subject.start_time).to eq(automation.created_at)
    end
  end

  describe '#end_time' do
    context 'with no steps' do
      it 'returns nil' do
        expect(subject.end_time).to be_nil
      end
    end

    context 'with step but no pipeline job' do
      before do
        step # Create the step
      end

      it 'returns nil' do
        expect(subject.end_time).to be_nil
      end
    end

    context 'with step and pipeline job but no harvest reports' do
      let(:pipeline_job) { create(:pipeline_job, automation_step: step, pipeline: pipeline) }

      before do
        step.pipeline_job = pipeline_job
      end

      it 'returns nil' do
        expect(subject.end_time).to be_nil
      end
    end

    context 'with step, pipeline job and harvest reports' do
      let(:pipeline_job) { create(:pipeline_job, automation_step: step, pipeline: pipeline) }
      let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
      let(:extraction_job) { create(:extraction_job) }
      let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }
      let(:report_time) { 1.hour.ago }

      before do
        step.pipeline_job = pipeline_job
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed',
               updated_at: report_time)
      end

      it 'returns the latest harvest report updated_at time' do
        expect(subject.end_time).to be_within(1.second).of(report_time)
      end
    end
  end

  describe '#total_duration' do
    context 'with no end time' do
      it 'returns 0' do
        allow(subject).to receive(:end_time).and_return(nil)
        expect(subject.total_duration).to eq(0)
      end
    end

    context 'with end time' do
      let(:start_time) { 2.hours.ago }
      let(:end_time) { 1.hour.ago }

      it 'returns the difference between end_time and start_time' do
        allow(subject).to receive(:start_time).and_return(start_time)
        allow(subject).to receive(:end_time).and_return(end_time)
        expect(subject.total_duration).to be_within(1.second).of(end_time - start_time)
      end
    end
  end

  describe '#stats' do
    it 'returns a hash with all the summary information' do
      allow(subject).to receive(:start_time).and_return(Time.current)
      allow(subject).to receive(:end_time).and_return(Time.current)
      allow(subject).to receive(:total_duration).and_return(3600)
      allow(subject).to receive(:total_metrics).and_return({})
      allow(subject).to receive(:step_metrics).and_return([])

      stats = subject.stats
      expect(stats).to be_a(Hash)
      expect(stats.keys).to contain_exactly(:start_time, :end_time, :total_duration, :total_metrics, :step_metrics)
    end
  end

  describe '#total_metrics' do
    context 'with no pipeline jobs' do
      it 'returns empty metrics' do
        expect(subject.total_metrics).to eq(AutomationSummary::EMPTY_METRICS)
      end
    end

    context 'with pipeline jobs and harvest reports' do
      let(:pipeline_job) { create(:pipeline_job, automation_step: step, pipeline: pipeline) }
      let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
      let(:extraction_job) { create(:extraction_job) }
      let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }

      before do
        step.pipeline_job = pipeline_job
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed',
               pages_extracted: 10,
               records_transformed: 8,
               records_loaded: 5,
               records_rejected: 2,
               records_deleted: 1)
        
        # Create another report with more metrics
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed',
               pages_extracted: 5,
               records_transformed: 4,
               records_loaded: 3,
               records_rejected: 1,
               records_deleted: 0)
      end

      it 'aggregates metrics from all harvest reports' do
        expect(subject.total_metrics).to eq({
          pages_extracted: 15,
          records_transformed: 12,
          records_loaded: 8,
          records_rejected: 3,
          records_deleted: 1
        })
      end
    end
  end

  describe '#step_metrics' do
    context 'with no steps' do
      it 'returns an empty array' do
        expect(subject.step_metrics).to eq([])
      end
    end

    context 'with steps' do
      let(:pipeline_job) { create(:pipeline_job, automation_step: step, pipeline: pipeline) }
      let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
      let(:extraction_job) { create(:extraction_job) }
      let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }

      before do
        step # Create the step
      end

      it 'returns an array with step metrics' do
        expect(subject.step_metrics).to be_an(Array)
        expect(subject.step_metrics.first).to have_key(:step)
        expect(subject.step_metrics.first[:step]).to eq(step)
      end

      context 'with harvest reports' do
        before do
          step.pipeline_job = pipeline_job
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                 extraction_status: 'completed', 
                 transformation_status: 'completed', 
                 load_status: 'completed',
                 delete_status: 'completed',
                 pages_extracted: 10,
                 records_transformed: 8,
                 records_loaded: 5,
                 records_rejected: 2,
                 records_deleted: 1)
        end

        it 'includes metrics for the step' do
          metrics = subject.step_metrics.first[:metrics]
          expect(metrics).to include(
            pages_extracted: 10,
            records_transformed: 8,
            records_loaded: 5,
            records_rejected: 2,
            records_deleted: 1
          )
        end
      end
    end
  end

  describe '#collect_step_metrics' do
    let(:pipeline_job) { create(:pipeline_job, automation_step: step, pipeline: pipeline) }
    let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
    let(:extraction_job) { create(:extraction_job) }
    let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }

    context 'with no pipeline job' do
      it 'returns nil' do
        expect(subject.send(:collect_step_metrics, step)).to be_nil
      end
    end

    context 'with pipeline job but no harvest reports' do
      before do
        step.pipeline_job = pipeline_job
      end

      it 'returns nil' do
        expect(subject.send(:collect_step_metrics, step)).to be_nil
      end
    end

    context 'with pipeline job and harvest reports' do
      before do
        step.pipeline_job = pipeline_job
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed',
               pages_extracted: 10,
               records_transformed: 8,
               records_loaded: 5,
               records_rejected: 2,
               records_deleted: 1)
      end

      it 'returns metrics for the step' do
        metrics = subject.send(:collect_step_metrics, step)
        expect(metrics).to include(
          pages_extracted: 10,
          records_transformed: 8,
          records_loaded: 5,
          records_rejected: 2,
          records_deleted: 1
        )
      end
    end
  end
end 