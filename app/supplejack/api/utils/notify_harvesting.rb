# frozen_string_literal: true

module Api
  module Utils
    class NotifyHarvesting
      def initialize(destination, source_id, harvesting)
        @api_source = Harvester::Source.new(destination)
        @source_id = source_id
        @harvesting = harvesting
      end

      def call
        id = find_source['_id']
        update_harvesting(id)
      end

      private

      def find_source
        Rails.logger.info("NotifyHarvesting requesting source object \"#{@source_id}\"")
        @api_source.index(
          source: { source_id: @source_id }
        ).body.first
      end

      def update_harvesting(id)
        Rails.logger.info("NotifyHarvesting update source with id \"#{id}\"")
        return if id.empty?

        @api_source.put(
          id, source: { harvesting: @harvesting }
        )
      end
    end
  end
end
