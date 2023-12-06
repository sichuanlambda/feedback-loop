class AddUserToScreenshotAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_reference :screenshot_analyses, :user, null: false, foreign_key: true
  end
end
