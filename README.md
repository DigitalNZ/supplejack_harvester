# Supplejack Harvester

## This project is a work in progress and is not ready to be run in production environments. It is subject to change at any time and existing versions may not be compatible with new versions.

The Supplejack Harvester performs the data ingestion process for the Supplejack API. If you are familiar with the existing Supplejack stack, the Supplejack Harvester is a replacement for the Supplejack Worker and Supplejack Manager.

It uses the following technologies:

- Ruby on Rails
- React
- MySQL
- Sidekiq

## Setup

This application was developed using Ruby 3.2.5 on Rails 7.1.

To get up and running:

1. Clone this repository:

`git clone https://github.com/DigitalNZ/supplejack_harvester.git`

2. Follow these steps:

```bash
bundle install
yarn
cp config/application.yml.example config/application.yml

# Update the values config/application.yml
# ActiveRecord encryption keys can be generated with:
bin/rails db:encryption:init

# Secret key base can be generated with:
bin/rails secret

# OTP encryption keys can be generated with:
openssl rand -base64 10 | base64

# Create the database, run the migrations and seed data (users)
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# To run the application you can do:
bin/dev

# or to run the processes seperately:
bundle exec rails s
bundle exec sidekiq
bin/vite dev
```

## Job Priorities and Running Multiple Sidekiqs

The harvester supports running multiple sidekiqs through the Job Priorities environment variable. This is intended for separating workloads into different processes so low priority processes don't block high priority processes. To make use of this feature you need to run multiple sidekiqs in your environment and tell the harvester which priorities are available through the JOB_PRIORITIES environment variable. 

Inside of the config folder there are example configurations for different sidekiq instances using different queues, to start one you can run it like so:

`bundle exec sidekiq -C config/sidekiq_high_priority.yml`

Once the processes are running, you can tell the harvester about them by using the JOB_PRIORITIES environment variable, the priority name is expected to match the name of a sidekiq queue.

EG `JOB_PRIORITIES='high_priority,medium_priority,low_priority'`

If you do not pass this value Sidekiq will use the default priority. 

The expectation is that you are running the default configuration + any additional queues that you would like to use.

## COPYRIGHT AND LICENSING

SUPPLEJACK CODE - GNU GENERAL PUBLIC LICENCE, VERSION 3
Supplejack is a tool for aggregating, searching and sharing metadata records. Supplejack Harvester is a component of Supplejack. The Supplejack Harvester code is Crown copyright (C) 2023, New Zealand Government. Supplejack was created by DigitalNZ at the National Library of NZ and the Department of Internal Affairs. http://digitalnz.org/supplejack

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses / http://www.gnu.org/licenses/gpl-3.0.txt
