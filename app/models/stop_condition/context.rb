# app/models/stop_condition/context.rb
# frozen_string_literal: true

class StopCondition
  class Context
    # Only expose what is explicitly passed in
    attr_reader :response, :document, :body, :status, :headers

    def initialize(document)
      @document = document
      @response = document # legacy alias
      @body = document.body
      @status = document.status
      @headers =
        if document.respond_to?(:headers)
          document.headers
        elsif document.respond_to?(:response_headers)
          document.response_headers
        else
          {}
        end
    end

    # Prevent access to dangerous methods
    instance_methods.each do |method|
      undef_method(method) unless %i[
        __send__
        __id__
        object_id
        instance_eval
        instance_exec
      ].include?(method)
    end
  end
end
