# frozen_string_literal: true

module Transformation
  class TypeChecker
    attr_reader :faulty_value

    def initialize(value)
      @value = value
      @faulty_value = nil
    end

    def valid?
      check_value(@value)
    end

    def error
      return nil unless @faulty_value

      "Field contains a wrong type: #{@faulty_value.class}. The field returned: #{@value.inspect}"
    end

    private

    def check_value(val)
      if allowed_raw_type?(val)
        true
      elsif allowed_iterable_type?(val)
        if val.empty?
          true
        elsif val.is_a?(Array)
          val.all? { |item| check_value(item) }
        elsif val.is_a?(Hash)
          val.all? { |k, v| check_key_and_value(k, v) }
        else
          set_faulty(val)
          false
        end
      else
        set_faulty(val)
        false
      end
    end

    def check_key_and_value(key, value)
      # Keys must be allowed raw types
      return set_faulty(key) && false unless allowed_raw_type?(key)

      # Values can be raw types or nested iterables
      check_value(value)
    end

    def allowed_raw_type?(val)
      allowed_raw_types.any? { |type| val.is_a?(type) }
    end

    def allowed_iterable_type?(val)
      allowed_iterable_types.any? { |type| val.is_a?(type) }
    end

    def set_faulty(val)
      @faulty_value ||= val
      false
    end

    def allowed_iterable_types
      [Array, Hash]
    end

    def allowed_raw_types
      [NilClass, TrueClass, FalseClass, Integer, Float, String, Symbol]
    end
  end
end
