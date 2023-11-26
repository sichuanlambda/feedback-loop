# config/initializers/aws.rb

require 'aws-sdk-textract'

# Debugging: Output the credentials being loaded
puts "AWS Region from credentials: #{Rails.application.credentials.dig(:aws, :region)}"
puts "AWS Access Key ID from credentials: #{Rails.application.credentials.dig(:aws, :access_key_id)}"
puts "AWS Secret Access Key from credentials: [REDACTED]" # Do not print the secret access key

Aws.config.update({
  region: Rails.application.credentials.aws[:region],
  credentials: Aws::Credentials.new(
    Rails.application.credentials.aws[:access_key_id],
    Rails.application.credentials.aws[:secret_access_key]
  )
})
