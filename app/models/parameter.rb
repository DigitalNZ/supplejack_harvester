# frozen_string_literal: true

require 'ostruct'

class Parameter < ApplicationRecord
  belongs_to :request

  enum :kind, { query: 0, header: 1, slug: 2 }
  enum :content_type, { static: 0, dynamic: 1, incremental: 2 }

  # How #content is read when the request is built. Everything is stored as a string,
  # which is all a query string can carry, but the types in a payload matter to the
  # content source: a nested parameter is a JSON value, and a flag is a boolean rather
  # than the word "true".
  enum :value_type, { string: 0, integer: 1, boolean: 2, json: 3 }, prefix: :value

  BOOLEANS = %w[true false].freeze
  WHOLE_NUMBER = /\A[+-]?\d+\z/

  validate :value_type_is_declarable
  validate :content_matches_value_type

  # A parameter once it has been evaluated: a name, and a value whose type is intact.
  # The value does not go back through the record, whose content column casts a Hash or
  # an Integer to a String - which is how a nested payload used to reach the content
  # source as "{record: {status: :deleted}}".
  Value = Struct.new(:name, :value) do
    def to_h
      { name => value }
    end
  end

  def evaluate(response_object = nil)
    send(:"#{content_type}_evaluation", response_object)
  end

  def static_evaluation(_response_object)
    Value.new(name, typed_content)
  end

  def incremental_evaluation(response_object)
    Value.new(name, response_object.params[name].to_i + content.to_i)
  end

  # A dynamic parameter is typed by whatever its expression returns, so the result is
  # taken as it is: an expression returning a Hash is how a nested payload is written.
  def dynamic_evaluation(response_object)
    Value.new(name, evaluate_content(dynamic_subject(response_object)))
  rescue StandardError
    Value.new(name, "#{content}-evaluation-error".parameterize)
  end

  private

  # An expression mentioning the headers is handed the whole response to read; every
  # other one is handed the body, which is what an expression usually works from.
  # rubocop:disable Style/OpenStructUse
  def dynamic_subject(response_object)
    return response_object&.body unless content.include?('headers')

    OpenStruct.new(
      body: response_object&.body,
      headers: response_object&.response_headers,
      status: response_object&.status
    )
  end
  # rubocop:enable Style/OpenStructUse

  # The expression is written against a local named response, so the block has to take
  # it by that name even though nothing here reads it.
  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  def evaluate_content(subject)
    block = ->(response) { eval(content) }
    block.call(subject)
  end
  # rubocop:enable Lint/UnusedBlockArgument
  # rubocop:enable Security/Eval

  # Blank content is a parameter that is still being filled in - the editor saves the
  # type on its own - so it is read as the string it is rather than parsed.
  def typed_content
    return content if content.blank?

    case value_type
    when 'integer' then Integer(content, exception: false)
    when 'boolean' then content == 'true'
    when 'json' then JSON.parse(content)
    else content
    end
  end

  # Only a static query or header parameter declares a type. A dynamic one is typed by
  # what its expression returns, an incremental one is always a number, and a slug is a
  # path segment: Request#slug joins them into the URL, where anything but a string
  # lands as its own inspect output.
  def value_type_is_declarable
    return if value_string?
    return if static? && (query? || header?)

    errors.add(:value_type, 'can only be declared by a static query or header parameter')
  end

  # The content column holds a string, so a declared type is a promise about what that
  # string says. It is checked here rather than at evaluation, where a broken promise
  # would already be part of a request to the content source.
  def content_matches_value_type
    return if content.blank?

    case value_type
    when 'integer' then integer_content_error
    when 'boolean' then boolean_content_error
    when 'json' then json_content_error
    end
  end

  def integer_content_error
    errors.add(:content, 'must be a whole number') unless content.match?(WHOLE_NUMBER)
  end

  def boolean_content_error
    errors.add(:content, 'must be true or false') unless content.in?(BOOLEANS)
  end

  def json_content_error
    errors.add(:content, 'must be valid JSON') unless parsable_json?
  end

  def parsable_json?
    JSON.parse(content)
    true
  rescue JSON::ParserError
    false
  end
end
