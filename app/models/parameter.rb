# frozen_string_literal: true

require 'ostruct'

class Parameter < ApplicationRecord
  belongs_to :request

  enum :kind, { query: 0, header: 1, slug: 2 }
  enum :content_type, { static: 0, dynamic: 1, incremental: 2 }

  def evaluate(response_object = nil)
    send(:"#{content_type}_evaluation", response_object)
  end

  def static_evaluation(_response_object)
    self
  end

  def incremental_evaluation(response_object)
    Parameter.new(name:, content: response_object.params[name].to_i + content.to_i)
  end

  # rubocop:disable Lint/UnusedBlockArgument
  # rubocop:disable Security/Eval
  def dynamic_evaluation(response_object)
    Rails.logger.info "response_object: #{response_object}"
    Rails.logger.info "content: #{content}"
    Rails.logger.info 'TESTING'

    block = lambda do |response|
      eval(content)
    end

    Rails.logger.info "block: #{block}"

    parameter = Parameter.new(
      name:,
      content: block.call(OpenStruct.new(
                            {
                              body: response_object&.body,
                              headers: response_object&.response_headers
                            }
                          ))
    )

    Rails.logger.info "parameter:#{parameter}"
    parameter
  rescue StandardError => e
    Rails.logger.info "ERROR:#{e}"
    Parameter.new(
      name:,
      content: "#{content}-evaluation-error".parameterize
    )
  end
  # rubocop:enable Lint/UnusedBlockArgument
  # rubocop:enable Security/Eval

  def to_h
    return if slug?

    {
      name => content
    }
  end
end
