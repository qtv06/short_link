# frozen_string_literal: true

class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.string :original_url, null: false
      t.string :short_code, limit: 6, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
