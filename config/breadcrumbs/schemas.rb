crumb :schemas do
  link 'Schemas', schemas_path
  parent :root
end

crumb :schema do |schema|
  link schema.name_in_database, schema_path(schema)
  parent :schemas
end
