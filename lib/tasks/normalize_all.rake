namespace :styles do
  desc "Normalize all architectural styles in the database"
  task normalize_all: :environment do
    BuildingAnalysis.find_each do |analysis|
      begin
        # Check if h3_contents is a string and attempt to parse it as JSON
        if analysis.h3_contents.is_a?(String)
          contents = JSON.parse(analysis.h3_contents) rescue []
        else
          contents = analysis.h3_contents || []
        end

        # Ensure contents is an array
        contents = [contents] unless contents.is_a?(Array)

        normalized_styles = contents.map { |style| StyleNormalizer.normalize(style.to_s) }.compact.uniq
        analysis.update(h3_contents: normalized_styles)
      rescue => e
        puts "Error processing BuildingAnalysis ID #{analysis.id}: #{e.message}"
      end
    end
    puts "All architectural styles have been normalized."
  end
end
