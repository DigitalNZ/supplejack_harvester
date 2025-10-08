class AddFollowRedirectsToExtractionDefinition < ActiveRecord::Migration[7.2]
  def change
    add_column :extraction_definitions, :follow_redirects, :boolean, default: true
  end
end
