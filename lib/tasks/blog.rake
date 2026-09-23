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
      post.content_updated_at = Time.current if fresh || (post.changes.keys & BlogPost::CONTENT_ATTRIBUTES).any?
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

  desc 'Generate hero images (gpt-image-1) for published posts missing one. LIMIT=n to batch; SLUGS=a,b to target or regenerate specific posts; QUALITY=low|medium|high; STYLE="extra prompt text".'
  task generate_heroes: :environment do
    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    abort 'OpenAI API key not found' if api_key.blank?

    scope = BlogPost.where(published: true)
    scope = if ENV['SLUGS'].present?
              scope.where(slug: ENV['SLUGS'].split(',').map(&:strip))
            else
              scope.where("hero_image_url IS NULL OR hero_image_url = ''").order(:id)
            end
    limit = ENV['LIMIT'].to_i
    scope = scope.limit(limit) if limit.positive?
    quality = %w[low medium high].include?(ENV['QUALITY']) ? ENV['QUALITY'] : 'medium'

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    total = scope.count
    done = failed = 0

    scope.each do |post|
      prompt = HeroImage.prompt(post, style: ENV['STYLE'])
      response = HTTParty.post(
        'https://api.openai.com/v1/images/generations',
        body: { model: 'gpt-image-1', prompt: prompt, n: 1,
                size: '1536x1024', quality: quality }.to_json,
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

      png = Base64.decode64(image_b64)
      jpeg = HeroImage.compress(png)
      obj = s3.bucket('architecture-generated').object("blog-heroes/#{post.slug}.jpg")
      obj.put(body: jpeg, content_type: 'image/jpeg', cache_control: 'public, max-age=31536000')
      post.update_columns(hero_image_url: obj.public_url)
      done += 1
      puts "OK   #{post.slug} (#{done + failed}/#{total}) #{png.bytesize / 1024}KB png -> #{jpeg.bytesize / 1024}KB jpg"
      sleep 2
    rescue => e
      failed += 1
      puts "FAIL #{post.slug}: #{e.class} #{e.message.truncate(160)}"
      sleep 5
    end

    puts "Hero generation complete: #{done} generated, #{failed} failed, " \
         "#{BlogPost.where(published: true).where("hero_image_url IS NULL OR hero_image_url = ''").count} still missing"
  end

  desc 'Re-encode existing PNG hero images (blog-heroes/*.png) as web-sized JPEGs. No API cost.'
  task compress_heroes: :environment do
    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    scope = BlogPost.where("hero_image_url LIKE '%/blog-heroes/%.png'")
    puts "#{scope.count} PNG hero(es) to re-encode"
    scope.find_each do |post|
      png = HTTParty.get(post.hero_image_url, timeout: 60).body
      jpeg = HeroImage.compress(png)
      obj = s3.bucket('architecture-generated').object("blog-heroes/#{post.slug}.jpg")
      obj.put(body: jpeg, content_type: 'image/jpeg', cache_control: 'public, max-age=31536000')
      post.update_columns(hero_image_url: obj.public_url)
      puts "OK   #{post.slug} #{png.bytesize / 1024}KB -> #{jpeg.bytesize / 1024}KB"
    rescue => e
      puts "FAIL #{post.slug}: #{e.class} #{e.message.truncate(120)}"
    end
  end
end
