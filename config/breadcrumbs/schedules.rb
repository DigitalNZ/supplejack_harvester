crumb :schedules do
  link 'Schedules', schedules_path
  parent :root
end

crumb :schedule do |schedule|
  link schedule.name_in_database, schedule_path(schedule)
  parent :schedules
end

crumb :new_schedule do
  link 'New'
  parent :schedules
end

crumb :schedule do |schedule|
  link schedule.subject.name_in_database, schedule_path(schedule)
  parent :schedules
end
