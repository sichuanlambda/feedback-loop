class CreateScreenshotAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :screenshot_analyses do |t|
      t.text :extracted_text

      t.timestamps
    end
  end
end
