class BackfillJobCompletionSummaryId < ActiveRecord::Migration[7.2]
  def up
    JobCompletion.reset_column_information

    # Backfill only records that need it (NULL or invalid FK references)
    JobCompletion.find_each(batch_size: 1000) do |job_completion|
      next if job_completion.job_completion_summary_id.present? &&
              JobCompletionSummary.exists?(id: job_completion.job_completion_summary_id)

      job_type = if job_completion.extraction?
                   'ExtractionJob'
                 elsif job_completion.transformation?
                   'TransformationJob'
                 end

      summary = job_type ? JobCompletionSummary.find_by(
        job_id: job_completion.job_id,
        process_type: job_completion.process_type,
        job_type: job_type
      ) : nil

      if summary
        job_completion.update_columns(job_completion_summary_id: summary.id)
      else
        Rails.logger.warn "No JobCompletionSummary found for JobCompletion #{job_completion.id} (job_id: #{job_completion.job_id}, process_type: #{job_completion.process_type})"
      end
    end
  end

  def down
  end
end
