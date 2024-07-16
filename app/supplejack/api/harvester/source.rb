# frozen_string_literal: true

module Api
  module Harvester
    class Source < Request
      def index(params)
        get('/harvester/sources', params)
      end

      def put(id, params)
        super("/harvester/sources/#{id}", params)
      end
    end
  end
end
