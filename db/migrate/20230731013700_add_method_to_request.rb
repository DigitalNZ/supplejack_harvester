# frozen_string_literal: true

class AddMethodToRequest < ActiveRecord::Migration[7.0]
  def change
    add_column :requests, :http_method, :string
  end
end
