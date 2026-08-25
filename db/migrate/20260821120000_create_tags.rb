# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps

      t.index :name, unique: true
      t.index :slug, unique: true
    end

    # The join model behind Pipeline has_many :tags, through: :pipeline_tags.
    # pipeline_id gets no index of its own: it leads the composite unique index
    # below, which serves both the uniqueness constraint and its foreign key.
    create_table :pipeline_tags do |t|
      t.belongs_to :pipeline, null: false, foreign_key: true, index: false
      t.belongs_to :tag, null: false, foreign_key: true

      t.timestamps

      t.index %i[pipeline_id tag_id], unique: true
    end
  end
end
