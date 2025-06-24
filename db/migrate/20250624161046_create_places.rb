class CreatePlaces < ActiveRecord::Migration[7.1]
  def change
    create_table :places do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.decimal :latitude, precision: 10, scale: 8, null: false
      t.decimal :longitude, precision: 11, scale: 8, null: false
      t.integer :zoom_level, default: 12
      t.text :description
      t.text :content
      t.boolean :published, default: false
      t.boolean :featured, default: false
      t.string :meta_title
      t.string :meta_description

      t.timestamps
    end

    add_index :places, :slug, unique: true
    add_index :places, :name, unique: true
    add_index :places, :published
    add_index :places, :featured
  end
end
