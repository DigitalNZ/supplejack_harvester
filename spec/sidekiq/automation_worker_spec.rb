# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationWorker, type: :job do
  let(:automation_template) { create(:automation_template) }
  let(:automation) { create(:automation, automation_template: automation_template) }

  before do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  def queued_jobs
    described_class.jobs.pluck('args')
  end

  describe '#perform' do
    context 'when the automation does not exist' do
      it 'does not process the step' do
        worker = described_class.new

        expect(worker).not_to receive(:process_step)

        worker.perform(1231, 2000)
      end
    end

    context 'when the step does not exist' do
      it 'does not process the step' do
        worker = described_class.new

        expect(worker).not_to receive(:process_step)

        worker.perform(automation.id, 2000)
      end
    end

    context 'when a pipeline step has not started yet' do
      let(:step) { create(:automation_step, automation:, position: 0) }

      it 'creates a pipeline job for the step' do
        expect { described_class.new.perform(automation.id, step.id) }
          .to change { step.reload.pipeline_job }.from(nil)
      end

      it 'schedules a check on the step' do
        described_class.new.perform(automation.id, step.id)

        expect(queued_jobs).to eq [[automation.id, step.id]]
      end
    end

    context "when the step's pipeline job has been cancelled" do
      let(:step) { create(:automation_step, automation:, position: 0) }
      let!(:next_step) { create(:automation_step, automation:, position: 1) }

      before do
        create(:pipeline_job, automation_step: step, pipeline: step.pipeline, status: 'cancelled')
      end

      it 'stops checking on the step' do
        described_class.new.perform(automation.id, step.id)

        expect(queued_jobs).not_to include [automation.id, step.id]
      end

      it 'does not move on to the next step' do
        described_class.new.perform(automation.id, step.id)

        expect(queued_jobs).not_to include [automation.id, next_step.id]
      end
    end

    context "when the step's pipeline job has errored" do
      let(:step) { create(:automation_step, automation:, position: 0) }
      let!(:next_step) { create(:automation_step, automation:, position: 1) }

      before do
        create(:pipeline_job, automation_step: step, pipeline: step.pipeline, status: 'errored')
      end

      it 'stops checking on the step' do
        described_class.new.perform(automation.id, step.id)

        expect(queued_jobs).not_to include [automation.id, step.id]
      end

      it 'does not move on to the next step' do
        described_class.new.perform(automation.id, step.id)

        expect(queued_jobs).not_to include [automation.id, next_step.id]
      end
    end
  end
end
