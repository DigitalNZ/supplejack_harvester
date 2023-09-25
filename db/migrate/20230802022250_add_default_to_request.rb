# frozen_string_literal: true

class AddDefaultToRequest < ActiveRecord::Migration[7.0]
  def change
    change_column :requests, :http_method, :integer, default: 0
  end
end
