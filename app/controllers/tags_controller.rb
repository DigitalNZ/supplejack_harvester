# frozen_string_literal: true

# The list of every tag pipelines can be tagged with, where a mis-spelt or unused one is
# renamed or taken away so that it stops being offered as a suggestion. A tag is shared,
# so both reach further than one pipeline: renaming relabels it wherever it is carried,
# and deleting takes it off every pipeline at once.
class TagsController < ApplicationController
  before_action :find_tag, only: %i[edit update destroy]

  def index
    @tags = Tag.ordered.page(params[:page])
    @pipeline_counts = Tag.pipeline_counts
  end

  def edit; end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: t('.success')
    else
      flash.alert = t('.failure', errors: @tag.errors.full_messages.to_sentence)

      render :edit
    end
  end

  # The pipeline_tags the tag is deleted along with are its references from pipelines,
  # which the has_many :dependent option on Tag takes care of.
  def destroy
    if @tag.destroy
      redirect_to tags_path, notice: t('.success', name: @tag.name)
    else
      flash.alert = t('.failure')

      redirect_to tags_path
    end
  end

  private

  def find_tag
    @tag = Tag.find(params[:id])
  end

  def tag_params
    params.expect(tag: %i[name color])
  end
end
