class MigrateNames < ActiveRecord::Migration[7.2]
  def change
    # harvest job
    harvest_jobs = HarvestJob.all
    harvest_jobs.each do |job|
      job.name = "#{id}_#{harvest_definition.kind}"
      job.save
    end

    # harvest definition
    harvest_definitions = HarvestDefinition.all
    harvest_definitions.each do |definition|
      definition.name = "#{id}_#{kind}"
      definition.save
    end

    # extraction definition
    extraction_definitions = ExtractionDefinition.all
    extraction_definitions.each do |definition|
      definition.name = "#{id}_#{kind}-extraction"
      definition.save
    end

    # extraction jobs
    extraction_jobs = ExtractionJob.all
    extraction_jobs.each do |job|
      job.name = "#{id}_#{kind}-extraction"
      job.save
    end
  end
end
