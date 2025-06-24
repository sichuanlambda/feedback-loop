# Redis configuration for Heroku
if Rails.env.production?
  # Configure Redis for Heroku with SSL
  redis_url = ENV['REDIS_URL']
  
  if redis_url
    # Parse the URL to extract components
    uri = URI.parse(redis_url)
    
    # Configure Redis client with SSL options
    $redis = Redis.new(
      url: redis_url,
      ssl_params: {
        verify_mode: OpenSSL::SSL::VERIFY_NONE
      }
    )
    
    # Configure Sidekiq to use the same Redis instance
    Sidekiq.configure_server do |config|
      config.redis = {
        url: redis_url,
        ssl_params: {
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        }
      }
    end
    
    Sidekiq.configure_client do |config|
      config.redis = {
        url: redis_url,
        ssl_params: {
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        }
      }
    end
  end
end 