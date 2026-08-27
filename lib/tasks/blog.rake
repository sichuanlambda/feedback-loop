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

  desc 'Classify every post into a CTA category (FORCE=1 to reclassify all)'
  task classify_ctas: :environment do
    scope = ENV['FORCE'] == '1' ? BlogPost.all : BlogPost.where(cta_category: nil)
    scope.find_each do |post|
      post.update_columns(cta_category: BlogPost.infer_cta_category(post.title, post.slug))
    end
    puts "CTA categories: #{BlogPost.group(:cta_category).count.sort_by { |_k, v| -v }.to_h}"
  end

  desc 'Generate hero images for published posts missing one (gpt-image-1). LIMIT=n to batch.'
  task generate_heroes: :environment do
    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    abort 'OpenAI API key not found' if api_key.blank?

    scope = BlogPost.where(published: true)
                    .where("hero_image_url IS NULL OR hero_image_url = ''")
                    .order(:id)
    limit = ENV['LIMIT'].to_i
    scope = scope.limit(limit) if limit.positive?

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    total = scope.count
    done = failed = 0

    scope.each do |post|
      prompt = "Editorial hero photograph for an architecture blog post titled " \
               "\"#{post.title}\". Photorealistic, natural light, magazine quality. " \
               "No text, no watermarks, no borders."
      response = HTTParty.post(
        'https://api.openai.com/v1/images/generations',
        body: { model: 'gpt-image-1', prompt: prompt, n: 1,
                size: '1536x1024', quality: 'medium' }.to_json,
        headers: { 'Authorization' => "Bearer #{api_key}",
                   'Content-Type' => 'application/json' },
        timeout: 300
      )

      image_b64 = response.code == 200 ? JSON.parse(response.body).dig('data', 0, 'b64_json') : nil
      if image_b64.blank?
        failed += 1
        puts "FAIL #{post.slug} (HTTP #{response.code}): #{response.body.to_s.truncate(160)}"
        next
      end

      obj = s3.bucket('architecture-generated').object("blog-heroes/#{post.slug}.png")
      obj.put(body: Base64.decode64(image_b64), content_type: 'image/png')
      post.update_columns(hero_image_url: obj.public_url)
      done += 1
      puts "OK   #{post.slug} (#{done + failed}/#{total})"
      sleep 2
    rescue => e
      failed += 1
      puts "FAIL #{post.slug}: #{e.class} #{e.message.truncate(160)}"
      sleep 5
    end

    puts "Hero generation complete: #{done} generated, #{failed} failed, " \
         "#{BlogPost.where(published: true).where("hero_image_url IS NULL OR hero_image_url = ''").count} still missing"
  end
end
