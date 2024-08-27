# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SplitWorker, type: :job do
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }

  let(:pipeline) { create(:pipeline, name: 'National Library of New Zealand') }
  let(:extraction_definition) { create(:extraction_definition, pipeline:, split: true, split_selector: '//node') }

  describe '#perform' do
    context 'when the request is not paginated' do
      before do
        FileUtils.cp("#{Rails.root}/spec/support/split_example.json", "#{extraction_job.extraction_folder}/split_example.json")
      end

      it 'splits a large file into chunks of 100' do
        extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 1

        SplitWorker.new.perform(extraction_job.id)

        extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 2
      end

      it 'cleans up the tmp folder it creates' do
        expect(Dir.exist?("#{extraction_job.extraction_folder}/tmp")).to eq false

        SplitWorker.new.perform(extraction_job.id)

        expect(Dir.exist?("#{extraction_job.extraction_folder}/tmp")).to eq false
      end

      it 'names the new files following the appropriate naming convention' do
        SplitWorker.new.perform(extraction_job.id)

        expect(File.exist?("#{extraction_job.extraction_folder}/1/national-library-of-new-zealand_harvest-extraction-210__-__000000001.json"))
        expect(File.exist?("#{extraction_job.extraction_folder}/1/national-library-of-new-zealand_harvest-extraction-210__-__000000002.json"))
        expect(File.exist?("#{extraction_job.extraction_folder}/1/national-library-of-new-zealand_harvest-extraction-210__-__000000003.json"))
        expect(File.exist?("#{extraction_job.extraction_folder}/1/national-library-of-new-zealand_harvest-extraction-210__-__000000004.json"))
      end
    end

    context 'when the request is paginated' do
      before do
        FileUtils.mkdir_p("#{extraction_job.extraction_folder}/1")
        FileUtils.cp("#{Rails.root}/spec/support/split_example.json", "#{extraction_job.extraction_folder}/1/split_example_01.json")
        FileUtils.cp("#{Rails.root}/spec/support/split_example.json", "#{extraction_job.extraction_folder}/1/split_example_02.json")
      end

      it 'splits both files into many small ones that are unique from each other' do
        extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 2

        SplitWorker.new.perform(extraction_job.id)

        extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 4
      end
    end

    context 'when the split is not part of a harvest' do
      before do
        FileUtils.cp("#{Rails.root}/spec/support/split_example.json", "#{extraction_job.extraction_folder}/split_example.json")
      end

      it 'does not enqueue Transformation Workers' do
        expect(TransformationWorker).not_to receive(:perform_async)

        SplitWorker.new.perform(extraction_job.id)
      end
    end

    context 'when the split is part of a harvest' do
      before do
        FileUtils.cp("#{Rails.root}/spec/support/split_example.json", "#{extraction_job.extraction_folder}/split_example.json")
      end

      let!(:harvest_report)    { create(:harvest_report, pipeline_job:, harvest_job:) }
      let(:destination)        { create(:destination) }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:extraction_job)     { create(:extraction_job, extraction_definition:, harvest_job:) }

      it 'enqueues Transformation Workers to process the split files' do
        expect(TransformationWorker).to receive(:perform_async).exactly(2).times.and_call_original

        SplitWorker.new.perform(extraction_job.id)
      end

      it 'stops enqueuing TransformationWorkers if the pipeline has been cancelled' do
        expect(TransformationWorker).to receive(:perform_async).exactly(1).times.and_call_original
        pipeline_job.cancelled!

        SplitWorker.new.perform(extraction_job.id)
      end

      it 'updates the Harvest Report appropriately' do
        SplitWorker.new.perform(extraction_job.id)

        harvest_report.reload

        expect(harvest_report.transformation_workers_queued).to eq 2
      end
    end
  end
end
