# Sanitizes any object into JSON-safe data
def sanitize_record(record)
  case record
  when Hash
    record.each_with_object({}) do |(k, v), safe_hash|
      key = k.to_s
      safe_hash[key] = sanitize_record(v)
    end
  when Array
    record.map { |v| sanitize_record(v) }
  when Symbol
    record.to_s
  when Numeric, TrueClass, FalseClass, NilClass
    record
  when String
    record.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  else
    # Fallback for unexpected objects
    record.to_s
  end
end

def queue_load_worker(records)
  return if records.empty?

  @harvest_job.reload
  return if @harvest_job.cancelled? || @pipeline_job.cancelled?

  # Sanitize all records
  records_to_enqueue = records.map { |r| sanitize_record(r) }

  # Debugging: log any record that fails JSON serialization
  records_to_enqueue.each do |r|
    begin
      MultiJson.dump(r)
    rescue StandardError => e
      Airbrake.notify("Problematic record for LoadWorker: #{r.inspect}")
      Airbrake.notify("Error: #{e.message}")
    end
  end

  # Enqueue sanitized records
  LoadWorker.perform_async_with_priority(@pipeline_job.job_priority, @harvest_job.id, records_to_enqueue, @api_record_id)

  notify_harvesting_api
  @harvest_report.increment_load_workers_queued!
end

def queue_delete_worker(records)
  return if records.empty?

  # Sanitize all records
  records_to_enqueue = records.map { |r| sanitize_record(r) }

  # Debugging: log any record that fails JSON serialization
  records_to_enqueue.each do |r|
    begin
      MultiJson.dump(r)
    rescue StandardError => e
      Airbrake.notify("Problematic record for DeleteWorker: #{r.inspect}")
      Airbrake.notify("Error: #{e.message}")
    end
  end

  DeleteWorker.perform_async_with_priority(@pipeline_job.job_priority, records_to_enqueue, destination.id, @harvest_report.id)
  @harvest_report.increment_delete_workers_queued!
end

