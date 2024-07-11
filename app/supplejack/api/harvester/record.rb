# frozen_string_literal: true

module Api
  module Harvester
    class Record < Request
      def delete(id)
        put('/harvester/records/delete', id:)
      end
    end
  end
end
