class FixH3ContentsFormat < ActiveRecord::Migration[6.0]
  def up
    BuildingAnalysis.find_each do |analysis|
      next if analysis.h3_contents.nil? # Skip if h3_contents is nil

      # Attempt to parse the existing content to check if it's already valid JSON
      begin
        JSON.parse(analysis.h3_contents)
      rescue JSON::ParserError
        # If parsing fails, it's not valid JSON; let's assume it's a single string and wrap it in an array
        # If the h3_contents was nil, we treat it as an empty array
        new_contents = analysis.h3_contents.present? ? [analysis.h3_contents] : []
        analysis.update(h3_contents: new_contents.to_json)
      end
    end
  end

  def down
    # No need to revert data changes in this case
  end
end
