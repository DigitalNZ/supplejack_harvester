# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackfillStatuses do
  let(:destination) { create(:destination) }
  let(:pipeline)    { create(:pipeline) }
  let!(:block)      { create(:harvest_definition, pipeline:, kind: :harvest, position: 0) }

  # Old enough that nothing in flight can be mistaken for abandoned. The passes read
  # pipeline_jobs.updated_at, which a factory stamps as now, so it has to be pushed back.
  def age!(job)
    job.update_columns(updated_at: 3.days.ago)
    job
  end

  def run(status:, start_time: Time.zone.parse('2026-06-01 10:00'))
    job = create(:pipeline_job, pipeline:, destination:, status:, start_time:,
                                harvest_definitions_to_run: [block.id.to_s])
    age!(job)
  end

  def report_for(job, statuses, counters = {})
    harvest_job = create(:harvest_job, harvest_definition: block, pipeline_job: job)

    create(:harvest_report, pipeline_job: job, harvest_job:, kind: 'harvest', **statuses, **counters)
  end

  def config(env = {})
    BackfillStatuses::Config.new(BackfillStatuses::Config::DEFAULTS.merge('APPLY' => 'true').merge(env))
  end

  describe BackfillStatuses::Config do
    it 'is a dry run by default' do
      expect(described_class.new(described_class::DEFAULTS)).not_to be_apply
    end

    it 'refuses to exist with an abandoned status a run cannot hold' do
      expect { config('ABANDONED_STATUS' => 'abandoned') }.to raise_error(ArgumentError)
    end
  end

  describe BackfillStatuses::Runs do
    it 'ends a run left running though its block finished' do
      job = run(status: 'running')
      report_for(job, extraction_status: 'completed', transformation_status: 'completed',
                      load_status: 'completed', delete_status: 'completed')

      described_class.new(config).call

      expect(job.reload).to be_completed
    end

    it 'reports a run whose block errored as errored' do
      job = run(status: 'running')
      report_for(job, extraction_status: 'completed', transformation_status: 'completed',
                      load_status: 'errored', delete_status: 'completed')

      described_class.new(config).call

      expect(job.reload).to be_errored
    end

    # Its end time comes from what its blocks recorded, not from the day the repair ran - these
    # are the only record of when a harvest actually happened.
    it 'ends it when its blocks last did something, not now' do
      job = run(status: 'running')
      report = report_for(job, extraction_status: 'completed', transformation_status: 'completed',
                               load_status: 'completed', delete_status: 'completed')
      report.update_columns(load_updated_time: Time.zone.parse('2026-06-01 11:30'))

      described_class.new(config).call

      expect(job.reload.end_time).to be_within(1.second).of(Time.zone.parse('2026-06-01 11:30'))
    end

    it 'cancels a run that never started' do
      job = run(status: nil, start_time: nil)

      described_class.new(config).call

      expect(job.reload).to be_cancelled
    end

    it 'leaves a run that never started without invented times' do
      job = run(status: nil, start_time: nil)

      described_class.new(config).call

      expect(job.reload.end_time).to be_nil
    end

    it 'leaves a run whose block is still working alone' do
      job = run(status: 'running')
      report_for(job, extraction_status: 'completed', transformation_status: 'running',
                      load_status: 'queued', delete_status: 'queued')

      described_class.new(config).call

      expect(job.reload).to be_running
    end

    # The guard that keeps this safe to run while harvests are going: a run created moments ago
    # with no blocks yet is a worker part way through starting it, not an abandoned one.
    it 'leaves a run it has only just seen alone' do
      job = create(:pipeline_job, pipeline:, destination:, status: nil, start_time: nil,
                                  harvest_definitions_to_run: [block.id.to_s])

      described_class.new(config).call

      expect(job.reload.status).to be_nil
    end

    it 'writes nothing on a dry run' do
      job = run(status: 'running')
      report_for(job, extraction_status: 'completed', transformation_status: 'completed',
                      load_status: 'completed', delete_status: 'completed')

      tally = described_class.new(config('APPLY' => 'false')).call

      expect(job.reload).to be_running
      expect(tally.count(:would_completed)).to eq 1
    end

    # LIMIT is there to take a smaller first bite, so it has to bound what is written rather
    # than what is looked at.
    it 'stops after the limit, leaving the rest for a later run' do
      jobs = Array.new(3) do
        job = run(status: 'running')
        report_for(job, extraction_status: 'completed', transformation_status: 'completed',
                        load_status: 'completed', delete_status: 'completed')
        job
      end

      described_class.new(config('LIMIT' => '2')).call

      expect(jobs.map { |job| job.reload.status }).to eq %w[completed completed running]
    end

    # A historical run's configuration must survive the repair: saving through the model would
    # put it through RunConfiguration#derive_harvest_definitions_to_run.
    it 'leaves what the run was configured to do untouched' do
      job = run(status: 'running')
      report_for(job, extraction_status: 'completed', transformation_status: 'completed',
                      load_status: 'completed', delete_status: 'completed')

      expect { described_class.new(config).call }
        .not_to(change { job.reload.harvest_definitions_to_run })
    end
  end

  describe BackfillStatuses::Reports do
    it 'completes a block whose workers have all finished' do
      job = run(status: 'running')
      report = report_for(job, { extraction_status: 'completed', transformation_status: 'running',
                                 load_status: 'running', delete_status: 'queued' },
                          transformation_workers_queued: 1, transformation_workers_completed: 1,
                          load_workers_queued: 1, load_workers_completed: 1)

      described_class.new(config).call

      expect(report.reload.status).to eq 'completed'
    end

    it 'takes its end times from the block, not from now' do
      job = run(status: 'running')
      report = report_for(job, { extraction_status: 'completed', transformation_status: 'running',
                                 load_status: 'running', delete_status: 'queued' },
                          transformation_workers_queued: 1, transformation_workers_completed: 1,
                          load_workers_queued: 1, load_workers_completed: 1)
      report.update_columns(load_updated_time: Time.zone.parse('2026-06-01 11:30'))

      described_class.new(config).call

      expect(report.reload.load_end_time).to be_within(1.second).of(Time.zone.parse('2026-06-01 11:30'))
    end

    it 'leaves a block with workers still outstanding alone' do
      job = run(status: 'running')
      report = report_for(job, { extraction_status: 'completed', transformation_status: 'running',
                                 load_status: 'queued', delete_status: 'queued' },
                          transformation_workers_queued: 2, transformation_workers_completed: 1)

      described_class.new(config).call

      expect(report.reload.transformation_status).to eq 'running'
    end

    # Every worker check asks whether the extraction completed first, so while it has not there
    # is nothing the counts can decide.
    it 'cannot repair a block whose extraction never finished' do
      job = run(status: 'running')
      report = report_for(job, { extraction_status: 'running', transformation_status: 'running',
                                 load_status: 'running', delete_status: 'queued' },
                          transformation_workers_queued: 1, transformation_workers_completed: 1,
                          load_workers_queued: 1, load_workers_completed: 1)

      tally = described_class.new(config).call

      expect(report.reload.transformation_status).to eq 'running'
      expect(tally.count(:cannot_repair)).to eq 1
    end

    it 'writes nothing on a dry run' do
      job = run(status: 'running')
      report = report_for(job, { extraction_status: 'completed', transformation_status: 'running',
                                 load_status: 'running', delete_status: 'queued' },
                          transformation_workers_queued: 1, transformation_workers_completed: 1,
                          load_workers_queued: 1, load_workers_completed: 1)

      described_class.new(config('APPLY' => 'false')).call

      expect(report.reload.transformation_status).to eq 'running'
    end
  end
end
