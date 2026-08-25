# frozen_string_literal: true

module ErrorHandling
  extend ActiveSupport::Concern

  protected

  def render500
    format.json { render500_json }
  end

  def render500_json
    render json: {
      error: true,
      errorCode: 'InternalServerError',
      message: 'An unexpected error occured, check logs'
    }, status: :internal_server_error
  end

  # A record the editor can fix, as opposed to render500's "check logs": the messages
  # go back so the field that was refused can say why.
  def render422_json(record)
    messages = record.errors.full_messages

    render json: {
      error: true,
      errorCode: 'UnprocessableEntity',
      message: messages.to_sentence,
      errors: messages
    }, status: :unprocessable_content
  end
end
