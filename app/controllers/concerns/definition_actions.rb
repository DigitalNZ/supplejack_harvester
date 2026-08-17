# frozen_string_literal: true

# Creating and cloning a block's definitions goes the same way whichever of them it is: build
# it from the posted params, attach it to the block it was created under, and send the user to
# it - or back to the pipeline with the failure message. Kept in one place because the load
# definition made a third copy of it.
#
# The type is the definition's own word for itself - 'transformation', 'load' - and everything
# else follows from it: the model, the params method, the association and the path. The same
# derivation the pipeline cards already do (see app/views/pipelines/_card.html.erb).
module DefinitionActions
  extend ActiveSupport::Concern

  include DefinitionAttachment

  private

  # A definition with more to configure sends the user on to its own page; one that is
  # finished the moment it is created takes a success_path back to where they were.
  def create_definition(type, success_path: nil)
    definition = "#{type}_definition".camelize.constantize.new(send(:"#{type}_definition_params"))
    instance_variable_set(:"@#{type}_definition", definition)

    return definition_failure(definition) unless definition.save

    # Nothing for it to belong to, so it should not be left lying around. The block is the one
    # with the complaint, so it is the block's errors the user needs to read.
    unless attach_to_block(definition, type)
      definition.destroy

      return definition_failure(@harvest_definition)
    end

    redirect_to success_path || definition_path(type, definition), notice: t('.success')
  end

  # The one failure that stays on the page it came from, so the form can show its errors.
  def update_definition(type, definition)
    unless definition.update(send(:"#{type}_definition_params"))
      flash.alert = t('.failure')

      return render :show
    end

    redirect_to definition_path(type, definition), notice: t('.success')
  end

  def destroy_definition(type, definition)
    return definition_failure(definition, definition_path(type, definition)) unless definition.destroy

    redirect_to pipeline_path(@pipeline), notice: t('.success')
  end

  def clone_definition(type, definition)
    clone = definition.clone(@pipeline, send(:"#{type}_definition_params")['name'])

    return definition_failure(clone) unless clone.save

    @harvest_definition.update("#{type}_definition" => clone)
    flash.notice = t('.success')

    redirect_to definition_path(type, clone)
  end

  # Back to the pipeline unless the caller has somewhere better to send them.
  #
  # The reasons go in the alert because a redirect leaves the unsaved definition behind, and
  # the form that would have shown them beside the fields is built fresh on the next render.
  # Without them the user is told it did not work and nothing more, which is no help at all
  # when the reason is a priority disagreeing with a kind.
  #
  # t('.success') and t('.failure') resolve against the running controller and action rather
  # than where they are written, so each controller still gets its own messages.
  def definition_failure(definition, path = nil)
    reasons = definition.errors.full_messages.to_sentence.presence

    flash.alert = [t('.failure'), reasons].compact.join(': ')

    redirect_to(path || pipeline_path(@pipeline))
  end

  def definition_path(type, definition)
    send(:"pipeline_harvest_definition_#{type}_definition_path", @pipeline, @harvest_definition, definition)
  end
end
