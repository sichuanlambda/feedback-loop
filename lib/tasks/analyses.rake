namespace :analyses do
  desc 'Count BuildingAnalysis records stuck without html_content, grouped by image host'
  task blank_summary: :environment do
    require Rails.root.join('lib/blank_analysis_backfill')
    summary = BlankAnalysisBackfill.summary
    puts "blank: #{summary[:blank]}"
    puts "  with image:  #{summary[:with_image]}"
    puts "  image-less:  #{summary[:imageless]} (#{summary[:imageless_published]} still published)"
    puts 'by host:'
    summary[:by_host].each { |host, count| puts "  #{count}\t#{host}" }
  end

  desc 'Analyze a few blank records and print the results without saving (LIMIT=5, IDS=1,2)'
  task blank_preview: :environment do
    require Rails.root.join('lib/blank_analysis_backfill')
    BlankAnalysisBackfill.new(limit: (ENV['LIMIT'] || 5).to_i, ids: ENV['IDS']&.split(',')).preview
  end

  desc 'Repair image URLs on blank records and enqueue analysis jobs (LIMIT=, IDS=)'
  task blank_backfill: :environment do
    require Rails.root.join('lib/blank_analysis_backfill')
    BlankAnalysisBackfill.new(limit: ENV['LIMIT']&.to_i, ids: ENV['IDS']&.split(',')).run
  end

  desc 'Unpublish blank records that have no image and can never be analyzed'
  task hide_imageless: :environment do
    require Rails.root.join('lib/blank_analysis_backfill')
    BlankAnalysisBackfill.new.hide_imageless
  end

  desc 'Unpublish anything still without content once blank_backfill jobs have drained'
  task unpublish_remaining_blank: :environment do
    require Rails.root.join('lib/blank_analysis_backfill')
    BlankAnalysisBackfill.new.unpublish_remaining_blank
  end
end
