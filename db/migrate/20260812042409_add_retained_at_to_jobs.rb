# frozen_string_literal: true

# Null means not retained; the timestamp records when a user retained the job.
# A retained job's data is never deleted by the nightly cleanups.
# No index: both cleanups filter sets that are already scoped and small.
class AddRetainedAtToJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :extraction_jobs, :retained_at, :datetime
    add_column :pipeline_jobs, :retained_at, :datetime
  end
end
