# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteWorker, type: :worker do
  let(:harvest_report) { create(:harvest_report, extraction_status: 'completed', transformation_status: 'completed', delete_workers_queued: 1)  }
  let(:destination) { create(:destination) }

  describe '#perform' do
    context "when the job starts" do
      it "updates the harvest report to say that the delete is running" do
        DeleteWorker.new.perform("[]", destination.id, harvest_report.id)
        harvest_report.reload

        expect(harvest_report.delete_start_time).to be_present
      end
    end

    context "when the job ends" do
      context "when there are no errors" do
        it "increments the number of delete workers completed" do
          DeleteWorker.new.perform("[]", destination.id, harvest_report.id)
          harvest_report.reload
  
          expect(harvest_report.delete_workers_completed).to eq(1)
        end

        it "updates the harvest report to say that the delete is completed" do
          DeleteWorker.new.perform("[]", destination.id, harvest_report.id)
          harvest_report.reload

          expect(harvest_report.delete_end_time).to be_present
        end
      end

      context "when there is an error deleting a record" do
        before do
          allow(Delete::Execution).to receive(:new).and_raise("Error")
        end

        it "still increments the number of delete workers completed" do
          DeleteWorker.new.perform("[{\"transformed_record\":{\"internal_identifier\":\"test\"}}]", destination.id, harvest_report.id)
          harvest_report.reload

          expect(harvest_report.delete_workers_completed).to eq(1)
        end
      end

    end
  end
end