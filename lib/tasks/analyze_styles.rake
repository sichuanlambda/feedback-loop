require 'csv'

namespace :styles do
  desc "Analyze existing architectural styles and suggest normalizations"
  task analyze: :environment do
    styles = BuildingAnalysis.pluck(:h3_contents).flatten.compact
    style_counts = styles.group_by(&:itself).transform_values(&:count).sort_by { |_, v| -v }

    puts "Top 50 most common styles:"
    style_counts.first(50).each do |style, count|
      puts "#{style}: #{count}"
    end

    File.write('style_analysis.txt', style_counts.map { |s, c| "#{s}: #{c}" }.join("\n"))
    puts "Full analysis written to style_analysis.txt"

    # New code for suggesting normalizations
    normalized_styles = {}
    style_counts.each do |style, count|
      normalized = style.downcase
                        .gsub(/\d+%/, '')
                        .gsub(/[^\w\s-]/, '')
                        .strip
                        .gsub(/\s+/, ' ')

      normalized_styles[normalized] ||= []
      normalized_styles[normalized] << [style, count]
    end

    CSV.open('style_normalizations.csv', 'w') do |csv|
      csv << ['Normalized Style', 'Original Styles', 'Total Count']
      normalized_styles.sort_by { |_, v| -v.sum { |_, count| count } }.each do |normalized, originals|
        csv << [
          normalized,
          originals.map { |style, count| "#{style} (#{count})" }.join(', '),
          originals.sum { |_, count| count }
        ]
      end
    end

    puts "Normalization suggestions written to style_normalizations.csv"
  end
end
