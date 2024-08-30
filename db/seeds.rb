# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
# Dir[Rails.root.join('db/seeds/*.rb')].each do |file|
#   puts "Processing #{file.split('/').last}"
#   require file
# end

# Seed users
users = [{
  email: 'harvester@localhost',
  username: 'harvester',
  role: :harvester
}, {
  email: 'admin@localhost',
  username: 'admin',
  role: :admin
}]

users.each do |user|
  User.find_or_create_by!(email: user[:email]) do |u|
    u.username = user[:username]
    u.password = 'password'
    u.password_confirmation = 'password'
    u.role = user[:role]
    u.otp_required_for_login = false
    u.enforce_two_factor = false
  end
end
