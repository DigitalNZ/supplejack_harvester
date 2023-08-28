# Supplejack Harvester

## This project is a work in progress and is not ready to be run in production environments. It is subject to change at any time and existing versions may not be compatible with new versions. 

The Supplejack Harvester performs the data ingestion process for the Supplejack API. If you are familiar with the existing Supplejack stack, the Supplejack Harvester is a replacement for the Supplejack Worker and Supplejack Manager. 

It uses the following technologies:

- Ruby on Rails
- React
- MySQL
- Sidekiq


# Setup

This application was developed using Ruby 3.2.2 on Rails 7.

To get up and running:

1. Clone this repository:

`git clone https://github.com/DigitalNZ/supplejack_worker.git`


```bash
bundle install
yarn
cp config/application.yml.example config/application.yml
# update the values config/application.yml
bin/rails db:create
bin/rails db:migrate
bin/rails fixtures:load

# To run the application you can do:
foreman start -f Procfile.dev

# or to run the processes seperately:
bundle exec rails s
bin/vite dev
```

## COPYRIGHT AND LICENSING

SUPPLEJACK CODE - GNU GENERAL PUBLIC LICENCE, VERSION 3
Supplejack is a tool for aggregating, searching and sharing metadata records. Supplejack Harvester is a component of Supplejack. The Supplejack Harvester code is Crown copyright (C) 2023, New Zealand Government. Supplejack was created by DigitalNZ at the National Library of NZ and the Department of Internal Affairs. http://digitalnz.org/supplejack

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses / http://www.gnu.org/licenses/gpl-3.0.txt

