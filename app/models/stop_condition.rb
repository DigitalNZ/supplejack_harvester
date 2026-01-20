# frozen_string_literal: true

class StopCondition < ApplicationRecord
  belongs_to :extraction_definition

  def evaluate(document_extraction)
    document = document_extraction.document
    context = Context.new(document)

    Airbrake.notify(context)

    context.instance_eval(content)
  rescue StandardError => e
    Airbrake.notify(e)
    false
  end

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
