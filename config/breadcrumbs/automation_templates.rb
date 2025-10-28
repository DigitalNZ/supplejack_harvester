crumb :automation_templates do |pipeline|
  if pipeline
    link pipeline.name_in_database, pipeline_path(pipeline)
    parent :pipelines
  else
    link 'Automation Templates', automation_templates_path
    parent :root
  end
end

crumb :automation_template do |automation_template|
  link automation_template.name_in_database, automation_template_path(automation_template)
  parent :automation_templates
end

crumb :edit_automation_template do |automation_template|
  link "Edit"
  parent :automation_template, automation_template
end

crumb :automation_template_job do |pipeline_job|
  link "Automation job overview ##{pipeline_job.id}"
  parent :automation_template, pipeline_job.pipeline
end

crumb :automations do |automation_template|
  link "Automations", automation_template_path(automation_template, anchor: 'history')
  parent :automation_template, automation_template
end

crumb :automation do |automation|
  link automation.name_in_database, automation_path(automation)
  parent :automations, automation.automation_template
end
