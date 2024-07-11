# frozen_string_literal: true

module Delete
  class Execution
    include HttpClient

    def initialize(record, destination)
      @record = record
      @destination = destination
    end

    def call
      Api::Harvester::Record.new(@destination).delete(@record['transformed_record']['internal_identifier'])
    end
  end
end
