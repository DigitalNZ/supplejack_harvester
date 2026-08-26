# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::Request do
  let(:destination) { create(:destination) }

  describe 'the read timeout' do
    # Faraday merges a connection's request options over config/initializers/faraday.rb, so an
    # explicit nil here would clear the app-wide default rather than fall back to it.
    it 'leaves the app-wide default standing when none is given' do
      connection = described_class.new(destination).instance_variable_get(:@connection)

      expect(connection.options.timeout).to eq Faraday.default_connection_options.request.timeout
    end

    it 'overrides it for this connection only when one is given' do
      connection = described_class.new(destination, read_timeout: 180).instance_variable_get(:@connection)

      expect(connection.options.timeout).to eq 180
    end

    it 'leaves the open timeout alone either way' do
      connection = described_class.new(destination, read_timeout: 180).instance_variable_get(:@connection)

      expect(connection.options.open_timeout).to eq Faraday.default_connection_options.request.open_timeout
    end
  end
end
