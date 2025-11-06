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

crumb :extraction_definition do |harvest_definition, extraction_definition|
  link extraction_definition.name_in_database, pipeline_harvest_definition_extraction_definition_path(
    harvest_definition.pipeline, harvest_definition, extraction_definition
  )
  parent :pipeline, extraction_definition.pipeline
end

crumb :transformation_definition do |transformation_definition|
  link transformation_definition.name_in_database
  parent :pipeline, transformation_definition.pipeline
end

crumb :extraction_jobs do |harvest_definition, extraction_definition|
  link 'Extraction Jobs', pipeline_harvest_definition_extraction_definition_extraction_jobs_path(
    extraction_definition.pipeline, harvest_definition, extraction_definition
  )
  parent :extraction_definition, harvest_definition, extraction_definition
end

crumb :extraction_job do |harvest_definition, extraction_job|
  link extraction_job.id
  parent :extraction_jobs, harvest_definition, extraction_job.extraction_definition
end
