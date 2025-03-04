# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.5'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 7.1.5'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use mysql as the database for Active Record
gem 'mysql2', '~> 0.5'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.0'

gem 'elastic-apm'
gem 'vite_rails'

gem 'rack-mini-profiler'

gem 'jaro_winkler'

# handles pagination
gem 'kaminari'

gem 'foreman'

# used for pipelines
gem 'activerecord-nulldb-adapter' # allows to run pipeline without credentials

# user management
gem 'devise'
gem 'devise_invitable', '~> 2.0.0'
gem 'devise-two-factor'
gem 'rqrcode'

# extraction related
gem 'faraday', '~> 2.9'
gem 'faraday-follow_redirects'
gem 'jsonpath'
gem 'minitar'
gem 'nokogiri'
gem 'selenium-webdriver'
gem 'sidekiq'
gem 'yomu'
gem 'zlib'

# transformation related
gem 'webmock'

# used for schedules
gem 'sidekiq-cron'

# load related
gem 'retriable'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# For detecting filetype when extracting text from a file
gem 'aws-sdk-s3'
gem 'marcel'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'pry-byebug'
  gem 'rspec-rails'

  # syntax checker
  gem 'erb_lint', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  gem 'codeclimate_diff', github: 'boost/codeclimate_diff', tag: 'v0.1.10'
  gem 'letter_opener'

  # For code commenting
  gem 'yard'
end

group :test do
  # used in tests
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers'

  # generates code coverage reports
  gem 'simplecov'
end
