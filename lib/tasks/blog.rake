namespace :blog do
  desc 'Import/refresh blog posts from db/blog_content/*.json (idempotent, keyed by slug)'
  task import: :environment do
    dir = Rails.root.join('db', 'blog_content')
    files = Dir[dir.join('*.json')]
    abort "No JSON files found in #{dir}" if files.empty?

    created = updated = 0
    files.each do |file|
      data = JSON.parse(File.read(file))
      # Old-domain absolute links -> relative, so they work on any host
      # (the naked domain currently 403s everything)
      body = data['body_html'].to_s
                              .gsub(%r{https?://(?:www\.)?architecturehelper\.com/blog/}, '/blog/')
                              .gsub(%r{https?://(?:www\.)?architecturehelper\.com/?(?=["')<\s])}, '/')
      data['body_html'] = body
      post = BlogPost.find_or_initialize_by(slug: data['slug'])
      fresh = post.new_record?
      post.assign_attributes(
        title: data['title'],
        description: data['description'],
        body_html: data['body_html'],
        hero_image_url: data['hero_image'].presence,
        published_at: (Time.zone.parse(data['published_at']) rescue nil)
      )
      post.save!
      fresh ? created += 1 : updated += 1
    end
    puts "Blog import complete: #{created} created, #{updated} updated, #{BlogPost.count} total"
  end
end
