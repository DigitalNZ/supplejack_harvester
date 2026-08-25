# frozen_string_literal: true

# Where a block's transformed records get written, and which fragment of the destination
# record they land in. Until now that was derived from HarvestDefinition#kind, so a block
# could only write the way its kind implied - a harvest could not add a field to records
# owned by other sources without wiping their primary fragment.
class CreateLoadDefinitions < ActiveRecord::Migration[8.0]
  # Local models rather than the app's. HarvestDefinition loses #priority and
  # #required_for_active_record once the editor moves them onto the load definition, and a
  # migration reading them through the app class would break on that later commit.
  class HarvestDefinition < ActiveRecord::Base; end
  class LoadDefinition < ActiveRecord::Base; end

  # harvest -> primary_fragment, enrichment -> enrichment, preprocess -> file. Integers
  # rather than names for the same reason the models are local: this is a snapshot of what
  # the two enums meant when the migration was written, not a live reference to them.
  LOAD_KIND = { 0 => 0, 1 => 2, 2 => 3 }.freeze
  KIND_NAME = { 0 => 'primary_fragment', 1 => 'secondary_fragment', 2 => 'enrichment', 3 => 'file' }.freeze

  def up
    create_table :load_definitions do |t|
      t.text    :name
      t.integer :kind,     default: 0, null: false
      t.integer :priority, default: 0, null: false
      t.boolean :required_for_active_record, default: false, null: false
      t.bigint  :pipeline_id
      t.bigint  :last_edited_by_id

      t.timestamps

      # Matching extraction and transformation definitions, which are also named,
      # uniquely, and picked out of a list by that name in the pipeline editor.
      t.index :name, unique: true, length: 255
      t.index :pipeline_id
      t.index :last_edited_by_id
    end

    add_column :harvest_definitions, :load_definition_id, :bigint
    add_index :harvest_definitions, :load_definition_id

    backfill
  end

  def down
    remove_column :harvest_definitions, :load_definition_id
    drop_table :load_definitions
  end

  private

  # One load definition per existing block, carrying across the settings that used to live
  # on the block itself. load_definition_id stays nullable: a block created between this
  # running and the deploy that starts creating them has none, and HarvestDefinition#load_kind
  # falls back to deriving one from the block kind.
  def backfill
    HarvestDefinition.reset_column_information

    HarvestDefinition.where(load_definition_id: nil).find_each do |definition|
      kind = LOAD_KIND.fetch(definition.kind, 0)

      load_definition = LoadDefinition.create!(
        kind:,
        priority: definition.priority || 0,
        required_for_active_record: definition.required_for_active_record || false,
        pipeline_id: definition.pipeline_id
      )

      load_definition.update!(name: "#{load_definition.id}_#{KIND_NAME.fetch(kind)}-load")
      definition.update!(load_definition_id: load_definition.id)
    end
  end
end
