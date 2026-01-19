# frozen_string_literal: true

require 'ostruct'

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  # rubocop:disable Security/Eval
  def evaluate(response_object)
    Airbrake.notify("Response: #{response_object}")

    context = OpenStruct.new(
      body: response_object.body,
      headers: response_object.response_headers,
      status: response_object.status
    )

    eval(content, context.instance_eval { binding })
  rescue StandardError => e
    e
  end

  # rubocop:enable Security/Eval
  def to_h
    {
      id:,
      name:,
      content:,
      created_at:,
      updated_at:
    }
  end
end
