# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::Execution do
  let(:full_job)                      { create(:extraction_job, extraction_definition:) }
  let(:sample_job)                    { create(:extraction_job, kind: 'sample', extraction_definition:) }
  let(:extraction_definition)         { create(:extraction_definition, :figshare) }
  let(:request_one)                   { create(:request, :figshare_initial_request, extraction_definition:) }
  let(:request_two)                   { create(:request, :figshare_main_request, extraction_definition:) }

  before do
    stub_figshare_harvest_requests(request_one)
    stub_figshare_harvest_requests(request_two)
  end

  describe '#call' do
    context 'when running a full job' do
      let(:subject) { described_class.new(full_job, extraction_definition) }

      it 'saves the full response from the content source to the filesystem' do
        subject.call

        expect(File.exist?(full_job.extraction_folder)).to be true
        extracted_files = Dir.glob("#{full_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 5
      end
    end

    context 'when running a sample job' do
      let(:subject) { described_class.new(sample_job, extraction_definition) }

      it 'saves the first page from the content source to the filesystem' do
        subject.call

        expect(File.exist?(sample_job.extraction_folder)).to be true
        extracted_files = Dir.glob("#{sample_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 1
      end
    end

    context 'when the extraction definition has a throttle' do
      let(:extraction_job) { create(:extraction_job) }
      let(:extraction_definition) do
        create(:extraction_definition, :figshare, throttle: 1000, extraction_jobs: [extraction_job])
      end
      let(:subject) { described_class.new(extraction_job, extraction_definition) }

      it 'respects the throttle set in the extraction_definition' do
        allow(subject).to receive(:sleep)

        subject.call

        expect(subject).to have_received(:sleep).with(1.0).exactly(6).times
      end
    end

    context 'when the job has been cancelled' do
      let(:extraction_job) { create(:extraction_job, status: 'cancelled') }
      let(:extraction_definition) do
        create(:extraction_definition, :figshare, throttle: 500, extraction_jobs: [extraction_job])
      end
      let(:subject) { described_class.new(extraction_job, extraction_definition) }

      it 'does not extract further pages' do
        subject.call

        expect(File.exist?(extraction_job.extraction_folder)).to be true
        extracted_files = Dir.glob("#{extraction_job.extraction_folder}/**/*").select { |e| File.file? e }

        expect(extracted_files.count).to eq 2
      end
    end

    context 'when the job is part of a harvest' do
      let(:extraction_job)                  { create(:extraction_job) }
      let(:sample_extraction_job)           { create(:extraction_job, :sample) }
      let(:extraction_definition)           { create(:extraction_definition, :figshare) }
      let(:pipeline)                        { create(:pipeline) }
      let(:pipeline_job)                    { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition)              { create(:harvest_definition, pipeline:) }
      let(:destination)                     { create(:destination) }
      let!(:harvest_job)                    do
        create(:harvest_job, extraction_job:, harvest_definition:, pipeline_job:)
      end
      let!(:harvest_report)                 { create(:harvest_report, pipeline_job:, harvest_job:) }
      # A definition can only have one harvest job per pipeline job, so the
      # sample harvest runs in its own pipeline job.
      let(:sample_pipeline_job)             { create(:pipeline_job, pipeline:, destination:) }
      let!(:sample_harvest_job)             do
        create(:harvest_job, extraction_job: sample_extraction_job, harvest_definition:,
                             pipeline_job: sample_pipeline_job)
      end
      let!(:sample_harvest_report)          do
        create(:harvest_report, pipeline_job: sample_pipeline_job, harvest_job: sample_harvest_job)
      end
      let(:request_one)                     { create(:request, :figshare_initial_request, extraction_definition:) }
      let(:request_two)                     { create(:request, :figshare_main_request, extraction_definition:) }

      before do
        stub_figshare_harvest_requests(request_one)
        stub_figshare_harvest_requests(request_two)
      end

      context 'when it is a full harvest' do
        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        it 'enqueues 5 TransformationWorkers in sidekiq' do
          expect(TransformationWorker).to receive(:perform_async).exactly(5).times.and_call_original

          subject.call
        end
      end

      context 'when it is a sample harvest' do
        let(:subject) { described_class.new(sample_extraction_job, extraction_definition) }

        it 'enqueues 1 TransformationWorker in sidekiq' do
          expect(TransformationWorker).to receive(:perform_async).once.and_call_original

          subject.call
        end
      end

      context 'when the extraction needs to be split' do
        let(:extraction_definition) { create(:extraction_definition, pipeline:, split: true, split_selector: '//node') }
        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        it 'does not enqueue any TransformationWorkers in sidekiq' do
          expect(TransformationWorker).not_to receive(:perform_async)

          subject.call
        end
      end

      context 'when it is a harvest for a specific number of pages' do
        let(:pipeline_job) do
          create(:pipeline_job, page_type: 'set_number', pages: 3, destination:, pipeline:)
        end
        let!(:harvest_job) do
          create(:harvest_job, extraction_job:, harvest_definition:, pipeline_job:)
        end
        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        it 'enqueues 3 Transformation Workers in Sidekiq' do
          expect(TransformationWorker).to receive(:perform_async).exactly(3).times.and_call_original

          subject.call
        end
      end

      context 'when the block has its own page limit' do
        let(:pipeline_job) do
          create(:pipeline_job, destination:, pipeline:,
                                block_settings: {
                                  harvest_definition.id.to_s => { 'run' => true, 'input' => 'fresh', 'pages' => 2 }
                                })
        end
        let!(:harvest_job) do
          create(:harvest_job, extraction_job:, harvest_definition:, pipeline_job:)
        end
        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        it "stops at that block's number of pages" do
          expect(TransformationWorker).to receive(:perform_async).exactly(2).times.and_call_original

          subject.call
        end
      end

      context 'when the document has failed to be extracted' do
        before do
          stub_failed_figshare_harvest_requests(request_one)
          stub_failed_figshare_harvest_requests(request_two)
        end

        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        it 'enqueues 0 TransformationWorkers in sidekiq' do
          expect(TransformationWorker).to receive(:perform_async).exactly(0).times.and_call_original

          subject.call
        end
      end

      context 'when the extraction_definition format is JSON' do
        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        context 'when the extraction_definition pagination_type is token' do
          let(:extraction_definition) do
            create(:extraction_definition, format: 'JSON', page: 1, paginated: true)
          end
          let(:request_one) { create(:request, :inaturalist_initial_request, extraction_definition:) }
          let(:request_two) { create(:request, :inaturalist_main_request, extraction_definition:) }

          before do
            stub_inaturalist_harvest_requests(request_one,
                                              {
                                                1 => '0',
                                                2 => '2098031',
                                                3 => '4218778',
                                                4 => '7179629'
                                              })

            stub_inaturalist_harvest_requests(request_two,
                                              {
                                                1 => '0',
                                                2 => '2098031',
                                                3 => '4218778',
                                                4 => '7179629',
                                              })
          end

          it 'enqueues 4 TransformationWorkers in sidekiq' do
            expect(TransformationWorker).to receive(:perform_async).exactly(4).times.and_call_original

            subject.call
          end
        end
      end

      context 'when the extraction_definition format is ARCHIVE_JSON' do
        let(:extraction_definition) do
          create(:extraction_definition, format: 'ARCHIVE_JSON', page: 1)
        end
        let(:request_one) { create(:request, extraction_definition:) }
        let(:request_two) { create(:request, extraction_definition:) }
        let(:subject)     { described_class.new(extraction_job, extraction_definition) }

        let(:archive_body) do
          records = Array.new(3) { |index| { 'id' => index }.to_json }
          io = StringIO.new
          Minitar::Writer.open(io) do |tar|
            records.each_with_index do |record, index|
              tar.add_file_simple("record-#{index}.json", mode: 0o644, size: record.bytesize) do |entry|
                entry.write(record)
              end
            end
          end
          io.string
        end

        before do
          stub_request(:get, request_one.url).to_return(status: 200, body: archive_body, headers: {})
        end

        it 'enqueues a TransformationWorker for every record saved from the archive' do
          expect(TransformationWorker).to receive(:perform_async).exactly(3).times.and_call_original

          subject.call
        end

        it 'counts the archive records on the harvest report' do
          subject.call

          expect(harvest_report.reload.pages_extracted).to eq 3
          expect(harvest_report.reload.transformation_workers_queued).to eq 3
        end
      end

      context 'when the extraction_definition format is XML' do
        let(:subject) { described_class.new(extraction_job, extraction_definition) }

        context 'when the extraction_definition pagination_type is page' do
          let(:extraction_definition) do
            create(:extraction_definition, format: 'XML', paginated: true, page: 1)
          end
          let(:request_one) { create(:request, :freesound_initial_request, extraction_definition:) }
          let(:request_two) { create(:request, :freesound_main_request, extraction_definition:) }

          before do
            stub_freesound_harvest_requests(request_one)
            stub_freesound_harvest_requests(request_two)
          end

          it 'enqueues 4 TransformationWorkers in sidekiq' do
            expect(TransformationWorker).to receive(:perform_async).exactly(4).times.and_call_original

            subject.call
          end
        end

        context 'when the extraction_definition pagination_type is tokenised' do
          let(:extraction_definition) do
            create(:extraction_definition, format: 'XML', pagination_type: 'tokenised',
                                           page: 1, paginated: true)
          end
          let(:request_one)           { create(:request, :trove_initial_request, extraction_definition:) }
          let(:request_two)           { create(:request, :trove_main_request, extraction_definition:) }

          before do
            stub_trove_harvest_requests(request_one,
                                        {
                                          1 => '*',
                                          2 => 'AoErc3UyMzQwNjY5OTI=',
                                          3 => 'AoErc3UyMzQwNjcwOTI=',
                                          4 => 'AoErc3UyMzQwNjcxOTQ=',
                                          5 => 'AoErc3UyMzQwNjcyOTU='
                                        })
          end

          it 'enqueues 4 TransformationWorkers in sidekiq' do
            expect(TransformationWorker).to receive(:perform_async).exactly(4).times.and_call_original

            subject.call
          end
        end

        context 'when the same document is extracted multiple times' do
          let(:extraction_definition) do
            create(:extraction_definition, format: 'XML', pagination_type: 'tokenised', page: 1, paginated: true)
          end
          let(:request_one)           { create(:request, :trove_initial_request, extraction_definition:) }
          let(:request_two)           { create(:request, :trove_main_request, extraction_definition:) }

          before do
            stub_trove_harvest_requests(request_one,
                                        {
                                          1 => '*',
                                          2 => 'AoErc3UyMzQwNjY5OTI=',
                                          3 => 'AoErc3UyMzQwNjcwOTI=',
                                          4 => 'AoErc3UyMzQwNjcxOTQ=',
                                          5 => 'AoErc3UyMzQwNjcyOTU='
                                        })
          end

          it 'stops the harvest' do
            expect(TransformationWorker).to receive(:perform_async).exactly(4).times.and_call_original

            subject.call
          end
        end
      end
    end
  end

  context 'when a user has defined custom stop conditions' do
    let(:subject) { described_class.new(full_job, extraction_definition) }
    let(:extraction_definition) do
      create(:extraction_definition, format: 'JSON', page: 1, paginated: true)
    end
    let(:request_one) { create(:request, :inaturalist_initial_request, extraction_definition:) }
    let(:request_two) { create(:request, :inaturalist_main_request, extraction_definition:) }
    let!(:stop_condition) { create(:stop_condition, content: 'JsonPath.new("$.page").on(response).first == 1', extraction_definition:) }

    before do
      stub_inaturalist_harvest_requests(request_one,
                                        {
                                          1 => '0',
                                          2 => '2098031',
                                          3 => '4218778',
                                          4 => '7179629'
                                        })

      stub_inaturalist_harvest_requests(request_two,
                                        {
                                          1 => '0',
                                          2 => '2098031',
                                          3 => '4218778',
                                          4 => '7179629',
                                        })
    end

    it 'stops once a stop condition has been met' do
      expect(Extraction::DocumentExtraction).to receive(:new).exactly(1).times.and_call_original

      subject.call
    end
  end
end
