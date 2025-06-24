class AddImageFieldsToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :hero_image_url, :string
    add_column :places, :hero_image_alt, :string
    add_column :places, :representative_image_url, :string
    add_column :places, :content_generated_at, :datetime
    add_column :places, :image_source, :string, default: 'placeholder'
    
    add_index :places, :image_source
    add_index :places, :content_generated_at
  end
end 