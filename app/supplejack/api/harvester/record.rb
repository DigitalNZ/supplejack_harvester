# frozen_string_literal: true

module Api
  module Harvester
    class Record < Request
      def flush(params)
        post('/harvester/records/flush', params)
      end

      def create_batch(params)
        post('/harvester/records/create_batch', params)
      end

      def delete(id)
        put('/harvester/records/delete', id:)
      end
    end
  end
end
