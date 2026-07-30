# frozen_string_literal: true

class AddUniqueIndexToHarvestJobsOnPipelineJobAndHarvestDefinition < ActiveRecord::Migration[8.0]
  def up
    # The enrichment-queueing guard has always been check-then-create, so
    # production may hold duplicate (pipeline_job, harvest_definition) pairs.
    # Keep the oldest row of each pair so the index can be created.
    execute <<~SQL.squish
      DELETE duplicate FROM harvest_jobs duplicate
      INNER JOIN harvest_jobs original
        ON duplicate.pipeline_job_id = original.pipeline_job_id
        AND duplicate.harvest_definition_id = original.harvest_definition_id
        AND duplicate.id > original.id
    SQL

    add_index :harvest_jobs, %i[pipeline_job_id harvest_definition_id],
              unique: true,
              name: 'index_harvest_jobs_on_pipeline_job_and_harvest_definition'
  end

  def down
    remove_index :harvest_jobs, name: 'index_harvest_jobs_on_pipeline_job_and_harvest_definition'
  end
end
