class UpdateSitemapJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Updating sitemap..."
    
    begin
      # Load and execute sitemap configuration
      load Rails.root.join('config', 'sitemap.rb')
      
      Rails.logger.info "Sitemap updated successfully"
    rescue => e
      Rails.logger.error "Failed to update sitemap: #{e.message}"
      raise e
    end
  end
end 