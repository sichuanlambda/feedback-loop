class CreateDogRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :dog_ratings do |t|
      t.string :image
      t.string :caption

      t.timestamps
    end
  end
end
