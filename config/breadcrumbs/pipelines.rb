crumb :pipelines do
  link 'Pipelines', pipelines_path
  parent :root
end

crumb :pipeline do |pipeline|
  link pipeline.name_in_database, pipeline_path(pipeline)
  parent :pipelines
end

crumb :pipeline_jobs do |pipeline|
  link 'Jobs', pipeline_pipeline_jobs_path(pipeline)
  parent :pipeline, pipeline
end

crumb :pipeline_job do |pipeline_job|
  link pipeline_job.id
  parent :pipeline_jobs, pipeline_job.pipeline
end

crumb :extraction_definition do |pipeline, harvest_definition, extraction_definition|
  link extraction_definition.name_in_database, pipeline_harvest_definition_extraction_definition_path(
    pipeline, harvest_definition, extraction_definition
  )
  parent :pipeline, pipeline
end

crumb :transformation_definition do |pipeline, transformation_definition|
  link transformation_definition.name_in_database
  parent :pipeline, pipeline
end

crumb :extraction_jobs do |pipeline, harvest_definition, extraction_definition|
  link 'Extraction Jobs', pipeline_harvest_definition_extraction_definition_extraction_jobs_path(
    pipeline, harvest_definition, extraction_definition
  )
  parent :extraction_definition, pipeline, harvest_definition, extraction_definition
end

crumb :extraction_job do |pipeline, harvest_definition, extraction_job|
  link extraction_job.id
  parent :extraction_jobs, pipeline, harvest_definition, extraction_job.extraction_definition
end
