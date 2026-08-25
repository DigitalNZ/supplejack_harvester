# frozen_string_literal: true

# Shared report-and-log plumbing for the cleanup workers. Every logged line
# is also collected into @report so a console run can return what it did;
# the worker tag (log_tag) is only added on the logger line, where the
# reader lacks the console's context.
module CleanupReport
  private

  # find, not find_by: a typo'd id in the console should raise, not silently
  # sweep nothing.
  def log_scope(pipeline_id)
    return unless pipeline_id

    log("scoped to pipeline=#{pipeline_id} (#{Pipeline.find(pipeline_id).name})")
  end

  def log(message)
    line = "#{'[dry run] ' if @policy.dry_run?}#{message}"
    @report << line
    Rails.logger.info("#{log_tag} #{line}")
  end

  def report_failure(label, error)
    line = "failed #{label} #{error.class}: #{error.message}"
    @report << line
    Rails.logger.error("#{log_tag} #{line}")
    Airbrake.notify(error)
  end
end
