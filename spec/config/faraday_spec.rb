# frozen_string_literal: true

require 'rails_helper'

# config/initializers/faraday.rb assigns default_connection_options rather than merging into
# it, so an edit to either half silently drops the other - the timeouts were absent for
# exactly that reason. These guard that both halves survive and reach the connections the app
# builds. The values themselves are meant to be tuned by ENV, so only their presence and
# their reaching a real connection are asserted.
RSpec.describe 'config/initializers/faraday.rb' do
  it 'bounds how long a connection may take to open' do
    expect(Faraday.new.options.open_timeout).to be_positive
  end

  it 'bounds how long a host may take to answer' do
    expect(Faraday.new.options.timeout).to be_positive
  end

  it 'still identifies the harvester to the sources it asks' do
    expect(Faraday.new.headers['User-Agent']).to eq 'Supplejack Harvester v2.0'
  end

  it 'reaches the extraction connections' do
    connection = Extraction::Connection.new(url: 'https://example.com').instance_variable_get(:@connection)

    expect(connection.options.open_timeout).to eq Faraday.default_connection_options.request.open_timeout
  end

  it 'reaches the destination API connections' do
    connection = Api::Request.new(create(:destination)).instance_variable_get(:@connection)

    expect(connection.options.open_timeout).to eq Faraday.default_connection_options.request.open_timeout
  end
end
