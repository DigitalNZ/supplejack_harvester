crumb :tags do
  link 'Tags', tags_path
  parent :root
end

crumb :edit_tag do |tag|
  link 'Edit'
  parent :tags
end
