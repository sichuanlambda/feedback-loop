# config/initializers/aws.rb

require 'aws-sdk-textract'

# Prefer environment variables, fallback to credentials file if not found
aws_region = ENV['AWS_REGION'] || Rails.application.credentials.dig(:aws, :region)
aws_access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id)
aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key)

# Debugging: Output the credentials being loaded (remove these lines in production)
puts "AWS Region from credentials: #{aws_region}"
puts "AWS Access Key ID from credentials: #{aws_access_key_id}"
puts "AWS Secret Access Key from credentials: [REDACTED]" # Do not print the secret access key

Aws.config.update({
  region: aws_region,
  credentials: Aws::Credentials.new(
    aws_access_key_id,
    aws_secret_access_key
  )
})
