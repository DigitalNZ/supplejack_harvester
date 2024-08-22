class AddEvaluateJavascriptToExtractionDefinition < ActiveRecord::Migration[7.1]
  def change
    add_column :extraction_definitions, :evaluate_javascript, :boolean, default: false
  end
end
