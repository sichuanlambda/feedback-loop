require 'open-uri'

# Repairs BuildingAnalysis records whose html_content never got written.
#
# Batch imports from early 2026 left ~22% of the library rendering the
# "Hang tight, we're working on your analysis" placeholder forever, which is
# what a sizeable share of organic search traffic lands on.
#
# The GPT pipeline itself is fine — the images were unreachable. Each record
# needs its image_url made publicly fetchable and small enough for the vision
# API, after which the existing ProcessBuildingAnalysisJob does the real work.
#
#   BlankAnalysisBackfill.new(limit: 5).preview   # analyze, print, save nothing
#   BlankAnalysisBackfill.new.run                 # repair images + enqueue jobs
#   BlankAnalysisBackfill.new.hide_imageless      # unpublish the unfixable ones
class BlankAnalysisBackfill
  PUBLIC_BUCKET = 'architecture-explorer'.freeze
  PUBLIC_REGION = 'us-east-2'.freeze
  LEGACY_BUCKET = 'screenshotsearcher'.freeze
  LEGACY_REGION = 'us-east-1'.freeze

  # OpenAI rejects images over 20MB; several imports are 8-25MB straight off a
  # phone camera. Resizing also cuts page weight for the visitors who arrive
  # from search, which is the whole point of fixing these pages.
  MAX_BYTES = 4_000_000
  MAX_DIMENSION = 1600

  # Wikimedia 400s on originals and asks for a thumbnail URL instead.
  WIKIMEDIA_THUMB_WIDTH = 1280

  def initialize(limit: nil, ids: nil, logger: nil)
    @limit = limit
    @ids = ids
    @logger = logger || ->(msg) { puts msg }
    @stats = Hash.new(0)
  end

  def self.blank_scope
    BuildingAnalysis.where("html_content IS NULL OR html_content = ?", "")
  end

  def self.summary
    blank = blank_scope
    with_image = blank.where.not(image_url: [nil, ''])
    {
      blank: blank.count,
      with_image: with_image.count,
      imageless: blank.where(image_url: [nil, '']).count,
      imageless_published: blank.where(image_url: [nil, '']).where(visible_in_library: true).count,
      by_host: with_image.pluck(:image_url).map { |u| host_of(u) }.tally.sort_by { |_, v| -v }.to_h
    }
  end

  def self.host_of(url)
    URI.parse(url).host || 'relative-path'
  rescue StandardError
    'unparseable'
  end

  # Runs the real analysis on a handful of records and prints the result
  # without writing anything, so the output can be eyeballed before committing
  # to the full set.
  def preview
    records.each do |rec|
      url = resolve_public_url(rec, save: false)
      if url.blank?
        log "  ##{rec.id} SKIP — no usable image (#{rec.image_url.to_s[0, 60]})"
        next
      end

      response = GptService.new.send_building_analysis(url)
      if response.is_a?(Hash) && response['styles'].present?
        styles = response['styles'].map { |s| "#{s['name']} #{s['confidence']}%" }.join(', ')
        log "  ##{rec.id} OK  #{response['building_name']} — #{styles}"
        log "        #{response['overview'].to_s[0, 160]}"
      else
        log "  ##{rec.id} BAD response: #{response.inspect[0, 160]}"
      end
    end
    nil
  end

  # Repairs image_urls and hands each record to the existing job.
  def run
    records.each do |rec|
      url = resolve_public_url(rec, save: true)
      if url.blank?
        @stats[:unresolvable] += 1
        log "  ##{rec.id} SKIP — no usable image"
        next
      end

      ProcessBuildingAnalysisJob.perform_later(rec.id, url, rec.address.presence || 'N/A')
      @stats[:enqueued] += 1
      log "  ##{rec.id} enqueued (#{url[0, 70]})"
    rescue StandardError => e
      @stats[:errored] += 1
      log "  ##{rec.id} ERROR #{e.class}: #{e.message[0, 120]}"
    end

    log "enqueued=#{@stats[:enqueued]} unresolvable=#{@stats[:unresolvable]} errored=#{@stats[:errored]}"
    @stats
  end

  # Records with no image at all can never be analyzed, so they should stop
  # being served as library/SEO pages.
  def hide_imageless
    unpublish(self.class.blank_scope.where(image_url: [nil, '']), 'image-less')
  end

  # Run once the enqueued jobs have drained: anything still without content —
  # unreachable image, no building in the photo — should stop being served as a
  # page that promises an analysis is on its way.
  def unpublish_remaining_blank
    unpublish(self.class.blank_scope, 'still-blank')
  end

  private

  def unpublish(scope, label)
    scope = scope.where(visible_in_library: true)
    count = scope.count
    scope.update_all(visible_in_library: false)
    log "unpublished #{count} #{label} analyses"
    count
  end

  def log(msg)
    @logger.call(msg)
  end

  def records
    scope = self.class.blank_scope.where.not(image_url: [nil, '']).order(:id)
    scope = scope.where(id: @ids) if @ids.present?
    scope = scope.limit(@limit) if @limit
    scope
  end

  # Returns a URL OpenAI can actually fetch, re-hosting the image on the public
  # bucket when the stored one is private, oversized, or not a URL at all.
  # With save: true the repaired URL is persisted back onto the record.
  def resolve_public_url(rec, save:)
    original = rec.image_url.to_s

    source = case original
             when %r{\Ahttps?://#{Regexp.escape(PUBLIC_BUCKET)}\.s3}
               oversized?(original) ? original : (return original)
             when %r{\Ahttps?://#{Regexp.escape(LEGACY_BUCKET)}\.s3}
               presigned_legacy_url(original)
             when %r{\Ahttps?://upload\.wikimedia\.org}
               wikimedia_thumb_url(original)
             when %r{\A/proxy/fetch_street_view}
               street_view_url_from(original, rec)
             when %r{\Ahttps?://}
               original
             end

    return nil if source.blank?

    file = download(source)
    return nil if file.nil?

    file = shrink(file)
    url = upload_to_public_bucket(file, rec.id)
    return nil if url.blank?

    rec.update_column(:image_url, url) if save && url != original
    url
  end

  def presigned_legacy_url(url)
    key = URI.parse(url).path.sub(%r{\A/}, '')
    client = Aws::S3::Client.new(region: LEGACY_REGION)
    Aws::S3::Presigner.new(client: client)
                      .presigned_url(:get_object, bucket: LEGACY_BUCKET, key: key, expires_in: 900)
  rescue StandardError => e
    log "    presign failed: #{e.message[0, 100]}"
    nil
  end

  # The handful of wikimedia imports already point at /thumb/ paths that
  # Wikimedia now rejects (400/404) regardless of the width requested. Nothing
  # to salvage — they fall through to the unresolvable count and get
  # unpublished with the rest.
  def wikimedia_thumb_url(url)
    return url if url.include?('/thumb/')

    filename = File.basename(URI.parse(url).path)
    url.sub('/commons/', '/commons/thumb/') + "/#{WIKIMEDIA_THUMB_WIDTH}px-#{filename}"
  rescue StandardError
    nil
  end

  # Some imports stored the proxy path rather than the image it proxies to.
  # The address on the record (or in the path) is enough to re-fetch it.
  def street_view_url_from(path, rec)
    location = begin
      CGI.parse(URI.parse(path).query.to_s)['location'].first
    rescue StandardError
      nil
    end
    location = rec.address if location.blank?
    return nil if location.blank?

    api_key = Rails.application.credentials.google_maps[:api_key]
    "https://maps.googleapis.com/maps/api/streetview?size=1200x800" \
      "&location=#{URI.encode_www_form_component(location)}&key=#{api_key}"
  end

  def oversized?(url)
    size = URI.open(url, 'User-Agent' => user_agent) { |f| f.size }
    size.to_i > MAX_BYTES
  rescue StandardError
    false
  end

  def download(url)
    tempfile = Tempfile.new(['backfill', '.jpg'])
    tempfile.binmode
    URI.open(url, 'User-Agent' => user_agent, read_timeout: 30) { |remote| tempfile.write(remote.read) }
    tempfile.rewind
    tempfile
  rescue StandardError => e
    log "    download failed: #{e.class} #{e.message[0, 100]}"
    nil
  end

  def shrink(file)
    image = MiniMagick::Image.open(file.path)
    return file if image.width <= MAX_DIMENSION && image.height <= MAX_DIMENSION && File.size(file.path) <= MAX_BYTES

    image.resize "#{MAX_DIMENSION}x#{MAX_DIMENSION}>"
    image.format 'jpg'
    image.quality 85
    image.write(file.path)
    file.rewind
    file
  rescue StandardError => e
    log "    resize skipped: #{e.message[0, 80]}"
    file
  end

  def upload_to_public_bucket(file, id)
    key = "uploads/backfill_#{id}_#{Time.now.to_i}.jpg"
    object = Aws::S3::Resource.new(region: PUBLIC_REGION).bucket(PUBLIC_BUCKET).object(key)
    object.upload_file(file.path)
    object.public_url
  rescue StandardError => e
    log "    upload failed: #{e.message[0, 100]}"
    nil
  ensure
    file.close! if file.respond_to?(:close!)
  end

  def user_agent
    'ArchitectureHelper/1.0 (+https://app.architecturehelper.com)'
  end
end
