namespace :styles do
  desc "Normalize all existing building h3_contents to canonical style names"
  task normalize_all: :environment do
    puts "Normalizing styles for all building analyses..."

    updated = 0
    skipped = 0
    errors = 0

    BuildingAnalysis.where.not(h3_contents: [nil, '']).find_each do |building|
      begin
        original = JSON.parse(building.h3_contents)
        normalized = StyleNormalizer.normalize_array(original)

        if original != normalized
          building.update_column(:h3_contents, normalized.to_json)
          updated += 1
          if updated <= 10  # Show first 10 changes
            puts "  ID #{building.id}: #{original.inspect} → #{normalized.inspect}"
          end
        else
          skipped += 1
        end
      rescue JSON::ParserError => e
        errors += 1
        puts "  ERROR ID #{building.id}: #{e.message}"
      end
    end

    puts "\nDone. Updated: #{updated} | Unchanged: #{skipped} | Errors: #{errors}"
  end

  desc "Show current style distribution (before normalization)"
  task distribution: :environment do
    raw_counts = Hash.new(0)
    normalized_counts = Hash.new(0)

    BuildingAnalysis.where.not(h3_contents: [nil, '']).find_each do |building|
      begin
        styles = JSON.parse(building.h3_contents)
        styles.each { |s| raw_counts[s.strip] += 1 }

        normalized = StyleNormalizer.normalize_array(styles)
        normalized.each { |s| normalized_counts[s] += 1 }
      rescue JSON::ParserError
        next
      end
    end

    puts "RAW STYLES (top 30):"
    raw_counts.sort_by { |_, c| -c }.first(30).each do |style, count|
      puts "  #{count.to_s.rjust(4)} × #{style}"
    end

    puts "\nNORMALIZED STYLES (top 30):"
    normalized_counts.sort_by { |_, c| -c }.first(30).each do |style, count|
      puts "  #{count.to_s.rjust(4)} × #{style}"
    end

    puts "\nRaw unique styles: #{raw_counts.keys.count}"
    puts "Normalized unique styles: #{normalized_counts.keys.count}"
    puts "Reduction: #{raw_counts.keys.count - normalized_counts.keys.count} styles consolidated"
  end
end
