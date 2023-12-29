class AddHtmlContentToBuildingAnalysis < ActiveRecord::Migration[6.0]
  def change
    add_column :building_analyses, :html_content, :text
  end
end
