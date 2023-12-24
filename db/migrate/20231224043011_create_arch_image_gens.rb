class CreateArchImageGens < ActiveRecord::Migration[6.0]
  def change
    create_table :arch_image_gens do |t|
      # No need to explicitly define created_at
      t.timestamps
    end
  end
end
