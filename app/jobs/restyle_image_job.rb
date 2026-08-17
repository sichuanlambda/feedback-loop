require 'open-uri'

# Re-renders a user's uploaded photo (home exterior or interior room) in a
# chosen canonical architecture style via OpenAI's image *edits* endpoint.
# Unlike GenerateArchImageJob (text-to-image, JSON body), /v1/images/edits
# requires a multipart request with the source image as a file part.
class RestyleImageJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 2

  MAX_SOURCE_BYTES = 40.megabytes # gpt-image-1 edit limit is 50MB per image

  def perform(arch_image_gen_id)
    record = ArchImageGen.find_by(id: arch_image_gen_id)
    return unless record
    return if record.status == 'complete'

    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    raise 'OpenAI API key not found' if api_key.nil?

    source_file = download_source(record.source_image_url)

    begin
      response = HTTParty.post(
        'https://api.openai.com/v1/images/edits',
        body: {
          model: 'gpt-image-1',
          prompt: record.prompt,
          image: source_file,
          n: 1,
          size: 'auto',
          input_fidelity: 'high'
        },
        headers: { 'Authorization' => "Bearer #{api_key}" },
        timeout: 300
      )
    ensure
      source_file.close! rescue nil
    end

    unless response.code == 200
      Rails.logger.error "[RestyleImageJob] API error (HTTP #{response.code}): #{response.body}"
      record.update_columns(status: 'failed', error_message: "Image service error (HTTP #{response.code})")
      return
    end

    image_b64 = JSON.parse(response.body).dig('data', 0, 'b64_json')
    if image_b64.blank?
      record.update_columns(status: 'failed', error_message: 'No image data in response')
      return
    end

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    obj = s3.bucket('architecture-generated').object("restyles/#{SecureRandom.uuid}.png")
    obj.put(body: Base64.decode64(image_b64), content_type: 'image/png')

    record.update_columns(status: 'complete', image_url: obj.public_url, error_message: nil)
  rescue => e
    record&.update_columns(status: 'failed', error_message: e.message.truncate(250))
    raise
  end

  private

  # Downloads the S3 source image to a local tempfile whose extension matches
  # its content type — OpenAI infers the mime type from the filename.
  def download_source(url)
    raise 'No source image' if url.blank?

    downloaded = URI.open(url, 'rb')
    content_type = downloaded.respond_to?(:content_type) ? downloaded.content_type.to_s : ''
    ext = case content_type
          when %r{image/png}  then '.png'
          when %r{image/webp} then '.webp'
          else '.jpg'
          end

    file = Tempfile.new(['restyle_source', ext], binmode: true)
    IO.copy_stream(downloaded, file)
    downloaded.close if downloaded.respond_to?(:close)
    file.rewind
    raise 'Source image too large' if file.size > MAX_SOURCE_BYTES

    file
  end
end
