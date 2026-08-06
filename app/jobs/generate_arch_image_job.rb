class GenerateArchImageJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 2

  def perform(arch_image_gen_id)
    record = ArchImageGen.find_by(id: arch_image_gen_id)
    return unless record
    return if record.status == 'complete'

    api_key = Rails.env.production? ? ENV['GPT_API_KEY_PRODUCTION'] : Rails.application.credentials.openai[:api_key]
    raise 'OpenAI API key not found' if api_key.nil?

    response = HTTParty.post(
      'https://api.openai.com/v1/images/generations',
      body: {
        model: 'gpt-image-1',
        prompt: record.prompt,
        n: 1,
        size: '1024x1024'
      }.to_json,
      headers: {
        'Authorization' => "Bearer #{api_key}",
        'Content-Type' => 'application/json'
      },
      timeout: 300
    )

    unless response.code == 200
      Rails.logger.error "[GenerateArchImageJob] API error (HTTP #{response.code}): #{response.body}"
      record.update_columns(status: 'failed', error_message: "Image service error (HTTP #{response.code})")
      return
    end

    image_b64 = JSON.parse(response.body).dig('data', 0, 'b64_json')
    if image_b64.blank?
      record.update_columns(status: 'failed', error_message: 'No image data in response')
      return
    end

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    obj = s3.bucket('architecture-generated').object("path/to/store/#{SecureRandom.uuid}.png")
    obj.put(body: Base64.decode64(image_b64), content_type: 'image/png')

    record.update_columns(status: 'complete', image_url: obj.public_url, error_message: nil)
  rescue => e
    record&.update_columns(status: 'failed', error_message: e.message.truncate(250))
    raise
  end
end
