# frozen_string_literal: true

namespace :fixtures do
  desc 'Clears the extraction folder, loads the fixtures and launches the job for testing'
  task load: :environment do
    puts 'Clearing the extraction folder...'
    FileUtils.rm_rf Dir.glob("#{ExtractionJob::EXTRACTIONS_FOLDER}/*/*")
    FileUtils.rmdir Dir.glob("#{ExtractionJob::EXTRACTIONS_FOLDER}/*")

    puts 'Resetting the DB...'
    `bin/rails db:reset`

    puts 'Loading the fixtures...'
    `bin/rails db:fixtures:load`

    puts 'Launching the extraction jobs...'
    ExtractionJob.find_each do |job|
      job.create_folder
      ExtractionWorker.new.perform(job.id)
    end
  end
end
