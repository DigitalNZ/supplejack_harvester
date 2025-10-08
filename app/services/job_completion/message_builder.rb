# frozen_string_literal: true

module JobCompletion
  class MessageBuilder
    def self.build_message(error, details)
      if details[:stop_condition_name].present?
        build_stop_condition_message(details)
      elsif details[:field_name].present?
        "Transformation failed '#{details[:field_name]}'"
      else
        build_error_message(error)
      end
    end

    def self.build_stop_condition_message(details)
      if details[:stop_condition_type] == 'user'
        "Stop condition '#{details[:stop_condition_name]}' was triggered"
      else
        "System stop condition '#{details[:stop_condition_name]}' was triggered"
      end
    end

    def self.build_error_message(error)
      error ? "#{error.class.name}: #{error.message}" : 'Unknown error occurred'
    end
  end
end
