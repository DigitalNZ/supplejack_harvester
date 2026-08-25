# frozen_string_literal: true

# Null means not retained; the timestamp records when a user retained the job.
# A retained job's data is never deleted by the nightly cleanup.
# No index: the cleanup filters a set that is already scoped and small.
class AddRetainedAtToExtractionJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :extraction_jobs, :retained_at, :datetime
  end
end
