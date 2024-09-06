namespace :styles do
  desc "Test the StyleNormalizer with sample inputs"
  task test_normalizer: :environment do
    test_styles = [
      "Arts & Crafts",
      "art deco",
      "Mid-Century Modern",
      "MODERN",
      "Contemporary 80%",
      "farmhouse chic",
      "Industrial loft",
      "Scandinavian minimalist",
      "boho eclectic",
      "coastal grandmother",
      "Unknown Style",
      "Modern Industrial",
      "Rustic Modern",
      "Eclectic Bohemian",
      "Traditional Contemporary",
      "Minimalist Scandinavian"
    ]

    puts "Testing StyleNormalizer:"
    test_styles.each do |style|
      normalized = StyleNormalizer.normalize(style)
      puts "#{style} => #{normalized}"
    end
  end
end
