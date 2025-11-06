crumb :destinations do
  link "Destinations", destinations_path
  parent :root
end

crumb :destination do |destination|
  link destination.name_in_database, destination_path(destination)
  parent :destinations
end

crumb :edit_destination do |destination|
  link "Edit"
  parent :destination, destination
end

crumb :new_destination do
  link "New"
  parent :destinations
end
