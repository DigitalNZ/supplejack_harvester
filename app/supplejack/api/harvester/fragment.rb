# frozen_string_literal: true

module Api
  module Harvester
    class Fragment < Request
      def post(record_id, params)
        super("/harvester/records/#{record_id}/fragments", params)
      end
    end
  end
end
