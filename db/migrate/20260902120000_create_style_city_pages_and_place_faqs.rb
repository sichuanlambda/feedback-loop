class CreateStyleCityPagesAndPlaceFaqs < ActiveRecord::Migration[7.1]
  def change
    create_table :style_city_pages do |t|
      t.string :style_name, null: false
      t.string :city_slug, null: false
      t.string :city_name, null: false
      t.text :intro_html
      t.json :faq
      t.integer :building_count, default: 0, null: false
      t.datetime :generated_at

      t.timestamps
    end
    add_index :style_city_pages, [:style_name, :city_slug], unique: true

    add_column :places, :faq, :json
  end
end
