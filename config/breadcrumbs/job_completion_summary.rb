crumb :job_completion_summaries do
  link 'Job Completion Summaries', job_completion_summaries_path
  parent :root
end

crumb :job_completion_summary do |job_completion_summary|
  link job_completion_summary.pipeline_name, job_completion_summary_path(job_completion_summary)
  parent :job_completion_summaries
end
