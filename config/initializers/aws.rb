require 'aws-sdk-textract'

# Prefer environment variables, fallback to credentials file if not found
aws_region = ENV['AWS_REGION'] || Rails.application.credentials.dig(:aws, :region)
aws_access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id)
aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key)

Aws.config.update({
  region: aws_region,
  credentials: Aws::Credentials.new(
    aws_access_key_id,
    aws_secret_access_key
  )
})
