# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TextExtractionWorker, type: :job do
  let(:pipeline) { create(:pipeline, name: 'PDF Example') }
  let(:extraction_definition) { create(:extraction_definition, pipeline:, format: 'JSON', extract_text_from_file: true) }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }

  describe "#perform" do
    context 'when the PDF extraction is not part of a harvest' do

      context 'when the PDF has a text layer' do
        before do
          FileUtils.cp("#{Rails.root}/spec/support/example.pdf", "#{extraction_job.extraction_folder}/example__1234__01.json")
        end

        it 'converts a PDF into raw text' do
          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          TextExtractionWorker.new.perform(extraction_job.id)

          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1
        end

        it 'signifies if content has been extracted from a PDF' do
          TextExtractionWorker.new.perform(extraction_job.id)

          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          document = JSON.parse(File.read(extracted_files.first))
          process = JSON.parse(document['body'])['process']

          expect(process).to eq 'Extracted from application/pdf using Yomu'
        end

        it 'cleans up the tmp folder it creates' do
          expect(Dir.exist?("#{extraction_job.extraction_folder}/tmp")).to eq false

          TextExtractionWorker.new.perform(extraction_job.id)

          expect(Dir.exist?("#{extraction_job.extraction_folder}/tmp")).to eq false
        end

        it 'names the new files following as it was originally' do
          TextExtractionWorker.new.perform(extraction_job.id)

          expect(File.exist?("#{extraction_job.extraction_folder}/1/example__1234__01.json")).to eq(true)
        end

        it 'does not enqueue Transformation Workers' do
          expect(TransformationWorker).not_to receive(:perform_async)

          TextExtractionWorker.new.perform(extraction_job.id)
        end
      end

      context 'when the PDF does not have a text layer' do
        before do
          FileUtils.cp("#{Rails.root}/spec/support/example_needing_ocr.pdf", "#{extraction_job.extraction_folder}/1/example__1234__01.json")
        end

        it 'OCRs the PDF to add a text layer' do
          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          TextExtractionWorker.new.perform(extraction_job.id)

          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          document = JSON.parse(File.read(extracted_files.first))
          text = JSON.parse(document['body'])['text']

          expect(text).to include("AUCKLAND OFFICE")
        end

        it 'signifies if content has been extracted using OCR' do
          TextExtractionWorker.new.perform(extraction_job.id)

          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          document = JSON.parse(File.read(extracted_files.first))
          process = JSON.parse(document['body'])['process']

          expect(process).to eq 'Extracted from PDF using OCRmyPDF'
        end
      end

      context 'when the PDF is invalid' do
        before do
          FileUtils.cp("#{Rails.root}/spec/support/invalid_pdf.pdf", "#{extraction_job.extraction_folder}/1/example__1234__01.json")
        end

        it 'fails gracefully when dealing with an invalid PDF' do
          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          TextExtractionWorker.new.perform(extraction_job.id)

          extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

          expect(extracted_files.count).to eq 1

          document = JSON.parse(File.read(extracted_files.first))
          text = JSON.parse(document['body'])['text']

          expect(text).to include('OCR failed')
        end
      end
    end

    context 'when the PDF extraction is part of a harvest' do
      before do
        FileUtils.cp("#{Rails.root}/spec/support/example.pdf", "#{extraction_job.extraction_folder}/1/example__1234__01.json")
      end

      let!(:harvest_report)    { create(:harvest_report, pipeline_job:, harvest_job:) }
      let(:destination)        { create(:destination) }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:extraction_job)     { create(:extraction_job, extraction_definition:, harvest_job:) }

      it 'enqueues Transformation Workers to process the text from the PDF' do
        expect(TransformationWorker).to receive(:perform_async).exactly(1).times.and_call_original

        TextExtractionWorker.new.perform(extraction_job.id)
      end

      it 'updates the Harvest Report appropriately' do
        TextExtractionWorker.new.perform(extraction_job.id)

        harvest_report.reload

        expect(harvest_report.transformation_workers_queued).to eq 1
        expect(harvest_report.transformation_status).to eq 'queued'
        expect(harvest_report.load_status).to eq 'queued'
      end
    end

    context 'when the PDF extraction is part of an enrichment' do
      before do
        FileUtils.cp("#{Rails.root}/spec/support/example.pdf", "#{extraction_job.extraction_folder}/1/example__1234__01.json")
      end

      let(:destination) { create(:destination) }
      let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, pipeline:, format: 'JSON', extract_text_from_file: true) }
      let!(:harvest_report)    { create(:harvest_report, pipeline_job:, harvest_job:) }
      let(:destination)        { create(:destination) }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }
      let(:extraction_job)     { create(:extraction_job, extraction_definition:, harvest_job:) }

      it 'enqueues Transformation Workers to process the text from the PDF with the API Record ID' do
        expect(TransformationWorker).to receive(:perform_async).exactly(1).times.with(anything, anything, "1234").and_call_original
        TextExtractionWorker.new.perform(extraction_job.id)
      end
    end
  end
end
