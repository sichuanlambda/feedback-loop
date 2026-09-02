# Programmatic SEO content: city guides, style-in-city pages, FAQs.
#
#   heroku run rake "places:add_cities[Amsterdam,Houston,London]"
#   heroku run rake places:generate_faqs
#   heroku run rake "seo:style_city_pages[3]"
namespace :places do
  desc "Create + publish city guides for cities named in the buildings' city field, then generate content/FAQ"
  task :add_cities, [:names] => :environment do |_t, args|
    # Rake hands shell args over as ASCII-8BIT; re-tag so "Kraków" parameterizes.
    names = args.to_a.map { |n| n.to_s.dup.force_encoding('UTF-8').strip }.reject(&:blank?)
    abort "Usage: rake \"places:add_cities[Amsterdam,Houston]\"" if names.empty?

    created = []
    names.each do |name|
      if (existing = Place.find_by('LOWER(name) = ?', name.downcase))
        puts "#{name}: already exists (#{existing.slug}, published=#{existing.published?})"
        next
      end

      buildings = BuildingAnalysis.where(visible_in_library: true)
                                  .where('LOWER(city) = ?', name.downcase)
                                  .where.not(latitude: nil).where.not(longitude: nil)
      if buildings.count < 3
        puts "#{name}: only #{buildings.count} geocoded buildings, skipping"
        next
      end

      # Median centre resists the odd mis-geocoded building better than the
      # first-building coordinates AutoPlaceGenerator uses.
      lats = buildings.pluck(:latitude).sort
      lngs = buildings.pluck(:longitude).sort
      place = Place.new(
        name: name,
        latitude: lats[lats.size / 2],
        longitude: lngs[lngs.size / 2],
        zoom_level: 12,
        description: "Explore the architecture of #{name}. Discover #{buildings.count} analyzed buildings and their unique architectural styles.",
        published: true,
        featured: false
      )
      unless place.save
        puts "#{name}: FAILED #{place.errors.full_messages.join(', ')}"
        next
      end

      in_box = place.building_analyses_in_place.count
      puts "#{name}: created /places/#{place.slug} (#{in_box} buildings in bounding box), generating content..."
      ok = PlaceContentGenerator.new(place).generate_content_and_images
      place.reload
      words = ActionController::Base.helpers.strip_tags(place.content.to_s).split.size
      puts "  content=#{ok ? 'ok' : 'FAILED'} words=#{words} faq=#{Array(place.faq).size} hero=#{place.hero_image_url.present?}"
      created << place
    end

    if created.any?
      puts "Regenerating sitemap..."
      UpdateSitemapJob.perform_now
      puts "NOTE: Heroku dynos have an ephemeral filesystem, so the sitemap served in production is the one committed in public/. Copy this one back into the repo and deploy it (see README, Programmatic SEO content)."
    end
    puts "Done. Created #{created.size} place(s)."
  end

  desc "Generate FAQs for published places that have content but no FAQ yet"
  task generate_faqs: :environment do
    places = Place.published.where.not(content: [nil, '']).select { |p| p.faq.blank? }
    puts "#{places.size} place(s) need FAQs"
    places.each do |place|
      faq = PlaceContentGenerator.new(place).generate_faq
      puts "  #{place.name}: #{faq.size} questions"
      sleep 1
    end
    puts "Done."
  end
end

namespace :seo do
  desc "Generate intro + FAQ for every style-in-city pair with at least N buildings (default 3)"
  task :style_city_pages, [:min, :limit] => :environment do |_t, args|
    min = (args[:min] || StyleCityPage::MIN_BUILDINGS).to_i
    limit = args[:limit].present? ? args[:limit].to_i : nil

    pairs = StyleCityPage.indexable_pairs(min: min).sort_by { |_, c| -c }
    existing = StyleCityPage.generated.pluck(:style_name, :city_slug).to_set
    todo = pairs.reject { |(style, city), _| existing.include?([style, city.parameterize]) }
    todo = todo.first(limit) if limit
    puts "#{pairs.size} pairs with >= #{min} buildings, #{existing.size} already generated, #{todo.size} to do"

    done = failed = 0
    todo.each do |(style, city), count|
      variants = StyleNormalizer::CANONICAL_STYLES[style] || [style.downcase]
      buildings = BuildingAnalysis.where(visible_in_library: true).where(city: city)
                                  .where(variants.map { 'LOWER(h3_contents) LIKE ?' }.join(' OR '), *variants.map { |v| "%#{v}%" })
                                  .order(created_at: :desc).to_a
      page = StyleCityContentGenerator.new(style, city, buildings).generate!
      if page
        done += 1
        puts "  ok   #{style} in #{city} (#{count}) -> #{page.path}"
      else
        failed += 1
        puts "  FAIL #{style} in #{city}"
      end
      sleep 1
    end

    puts "Generated #{done}, failed #{failed}."
    if done > 0
      puts "Regenerating sitemap..."
      UpdateSitemapJob.perform_now
      puts "NOTE: Heroku dynos have an ephemeral filesystem, so the sitemap served in production is the one committed in public/. Copy this one back into the repo and deploy it (see README, Programmatic SEO content)."
    end
  end

  desc "Show style-in-city coverage"
  task style_city_status: :environment do
    pairs = StyleCityPage.indexable_pairs
    generated = StyleCityPage.generated.count
    puts "indexable pairs (>= #{StyleCityPage::MIN_BUILDINGS} buildings): #{pairs.size}"
    puts "generated pages: #{generated}"
    pairs.sort_by { |_, c| -c }.first(15).each { |(s, c), n| puts "  #{n}\t#{s} in #{c}" }
  end
end
