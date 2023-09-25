# frozen_string_literal: true

class RenameContentPartnerToContentSource < ActiveRecord::Migration[7.0]
  def change
    rename_table :content_partners, :content_sources

    rename_column :extraction_definitions, :content_partner_id, :content_source_id
    rename_column :harvest_definitions, :content_partner_id, :content_source_id
    rename_column :transformation_definitions, :content_partner_id, :content_source_id
  end
end
