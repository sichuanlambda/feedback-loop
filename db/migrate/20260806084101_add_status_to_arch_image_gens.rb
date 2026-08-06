class AddStatusToArchImageGens < ActiveRecord::Migration[7.1]
  def change
    add_column :arch_image_gens, :status, :string, default: 'complete', null: false
    add_column :arch_image_gens, :prompt, :text
    add_column :arch_image_gens, :error_message, :string
  end
end
