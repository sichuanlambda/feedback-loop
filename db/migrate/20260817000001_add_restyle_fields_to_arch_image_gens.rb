class AddRestyleFieldsToArchImageGens < ActiveRecord::Migration[7.1]
  def change
    add_column :arch_image_gens, :user_id, :integer
    add_column :arch_image_gens, :kind, :string, default: 'generate', null: false
    add_column :arch_image_gens, :style_name, :string
    add_column :arch_image_gens, :space_type, :string
    add_column :arch_image_gens, :source_image_url, :string

    add_index :arch_image_gens, :user_id
    add_index :arch_image_gens, :kind
  end
end
