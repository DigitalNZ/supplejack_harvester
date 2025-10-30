crumb :users do
  link 'Users', users_path
  parent :root
end

crumb :user do |user|
  link user.username_in_database, user_path(user)
  parent :users
end

crumb :edit_user do |user|
  link "Edit"
  parent :user, user
end

crumb :edit_profile do
  link "Edit profile"
  parent :root
end
