class CreateGptInteractions < ActiveRecord::Migration[7.1]
  def change
    create_table :gpt_interactions do |t|
      t.datetime :submitted_at
      t.integer :response_time
      t.text :user_input
      t.text :gpt_response

      t.timestamps
    end
  end
end
