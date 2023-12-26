class AddImageUrlToArchImageGens < ActiveRecord::Migration[7.1]
  def change
    add_column :arch_image_gens, :image_url, :string
  end
end
