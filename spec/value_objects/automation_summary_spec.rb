# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationSummary do
  let(:harvest_report1) do
    instance_double(
      "HarvestReport",
      pages_extracted: 10,
      records_transformed: 100,
      records_loaded: 90,
      records_rejected: 10,
      records_deleted: 5,
      duration_seconds: 60,
      extraction_start_time: Time.current - 2.hours,
      extraction_end_time: Time.current - 1.hour - 50.minutes
    )
  end

  let(:harvest_report2) do
    instance_double(
      "HarvestReport",
      pages_extracted: 15,
      records_transformed: 150,
      records_loaded: 140,
      records_rejected: 10,
      records_deleted: 3,
      duration_seconds: 90,
      extraction_start_time: Time.current - 1.hour,
      extraction_end_time: Time.current - 50.minutes
    )
  end

  let(:pipeline_job1) do
    instance_double(
      "PipelineJob",
      harvest_reports: [harvest_report1],
      created_at: Time.current - 2.hours - 10.minutes,
      start_time: Time.current - 2.hours,
      end_time: Time.current - 1.hour - 45.minutes
    )
  end

  let(:pipeline_job2) do
    instance_double(
      "PipelineJob",
      harvest_reports: [harvest_report2],
      created_at: Time.current - 1.hour - 10.minutes,
      start_time: Time.current - 1.hour,
      end_time: Time.current - 45.minutes
    )
  end

  let(:step1) do
    instance_double(
      "AutomationStep",
      id: 1,
      pipeline_job: pipeline_job1
    )
  end

  let(:step2) do
    instance_double(
      "AutomationStep",
      id: 2,
      pipeline_job: pipeline_job2
    )
  end

  let(:steps) { [step1, step2] }
  
  let(:automation_steps) do
    # Create a double that acts like an ActiveRecord relation
    instance_double("ActiveRecord::Relation").tap do |relation|
      allow(relation).to receive(:includes).and_return(steps)
    end
  end
  
  let(:automation) do
    instance_double(
      "Automation",
      id: 1,
      automation_steps: automation_steps
    )
  end

  subject(:summary) { described_class.new(automation) }

  describe "#initialize" do
    it "initializes with an automation instance" do
      expect(summary.automation).to eq(automation)
    end

    it "loads steps with included associations" do
      expect(automation.automation_steps).to receive(:includes).with(:pipeline, pipeline_job: :harvest_reports)
      described_class.new(automation)
    end
  end

  describe "#total_metrics" do
    it "calculates the sum of all metrics across steps" do
      expect(summary.total_metrics).to eq({
        pages_extracted: 25,        # 10 + 15
        records_transformed: 250,   # 100 + 150
        records_loaded: 230,        # 90 + 140
        records_rejected: 20,       # 10 + 10
        records_deleted: 8          # 5 + 3
      })
    end

    context "when there are no harvest reports" do
      let(:empty_pipeline_job) do
        instance_double("PipelineJob", 
          harvest_reports: [],
          start_time: Time.current - 30.minutes,
          end_time: Time.current - 25.minutes,
          created_at: Time.current - 35.minutes
        )
      end
      
      let(:empty_step) do
        instance_double("AutomationStep", id: 3, pipeline_job: empty_pipeline_job)
      end
      
      let(:steps) { [empty_step] }
      
      let(:automation_steps) do
        instance_double("ActiveRecord::Relation").tap do |relation|
          allow(relation).to receive(:includes).and_return(steps)
        end
      end

      it "returns zeros for all metrics" do
        expect(summary.total_metrics).to eq({
          pages_extracted: 0,
          records_transformed: 0,
          records_loaded: 0,
          records_rejected: 0,
          records_deleted: 0
        })
      end
    end
  end

  describe "#step_metrics" do
    it "calculates metrics for each step" do
      step_metrics = summary.step_metrics
      
      expect(step_metrics.size).to eq(2)
      expect(step_metrics.first[:step]).to eq(step1)
      expect(step_metrics.last[:step]).to eq(step2)
      
      # Verify metrics structure
      expect(step_metrics.first).to have_key(:metrics)
      expect(step_metrics.first[:metrics]).to include(
        pages_extracted: 10,
        records_transformed: 100,
        records_loaded: 90,
        records_rejected: 10,
        records_deleted: 5,
        active_time: 60,
        queue_time: a_kind_of(Integer)
      )
      
      # Verify waiting_time logic - second step should wait after first step ends
      expect(step_metrics.last[:waiting_time]).to be_positive
    end
  end

  describe "#total_duration" do
    it "calculates the total time from earliest start to latest end" do
      # The automation spans from (current - 2.hours - 10.minutes) to (current - 45.minutes)
      # So it should be approximately 1 hour and 25 minutes in seconds
      expected_duration = ((2.hours + 10.minutes) - 45.minutes).to_i
      expect(summary.total_duration).to be_within(5).of(expected_duration)
    end
  end

  describe "#active_duration" do
    it "calculates the total active processing time across steps" do
      # Step 1: (end_time - start_time) = 15 minutes
      # Step 2: (end_time - start_time) = 15 minutes
      # Total: 30 minutes
      expect(summary.active_duration).to be_within(5).of(30.minutes.to_i)
    end
  end

  describe "#queue_duration" do
    it "calculates the time spent waiting in queue" do
      # Total duration - active duration
      expect(summary.queue_duration).to eq(summary.total_duration - summary.active_duration)
    end
  end

  describe "#start_time" do
    it "returns the earliest pipeline job creation time" do
      expect(summary.start_time).to eq(pipeline_job1.created_at)
    end
  end

  describe "#end_time" do
    it "returns the latest step end time" do
      expect(summary.end_time).to eq(pipeline_job2.end_time)
    end
  end

  context "with no pipeline jobs" do
    let(:step_without_job) do
      instance_double("AutomationStep", id: 3, pipeline_job: nil)
    end
    
    let(:steps) { [step_without_job] }
    
    let(:automation_steps) do
      instance_double("ActiveRecord::Relation").tap do |relation|
        allow(relation).to receive(:includes).and_return(steps)
      end
    end

    it "handles nil values gracefully" do
      expect(summary.total_duration).to eq(0)
      expect(summary.active_duration).to eq(0)
      expect(summary.queue_duration).to eq(0)
      expect(summary.start_time).to be_nil
      expect(summary.end_time).to be_nil
    end
  end
end 