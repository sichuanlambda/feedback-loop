module Api
  class BuildingAnalysesController < ApplicationController
    protect_from_forgery with: :null_session
    
    def index
      @building_analyses = BuildingAnalysis.all
      render json: @building_analyses.as_json(
        only: [:id, :address, :latitude, :longitude],
        methods: [:street_view_url]
      )
    end

    def nearby
      lat = params[:lat].to_f
      lng = params[:lng].to_f
      radius = params[:radius]&.to_f || 25.0 # Default 25 mile radius
      limit = params[:limit]&.to_i || 20

      if lat.zero? || lng.zero?
        render json: { error: 'lat and lng parameters are required' }, status: 400
        return
      end

      # Use Haversine formula to find nearby buildings
      # This is a simplified version - in production you'd want PostGIS or similar
      nearby_buildings = BuildingAnalysis.where(visible_in_library: true)
        .select("*, 
          (3959 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance", 
          lat, lng, lat)
        .having("distance < ?", radius)
        .order("distance ASC")
        .limit(limit)

      render json: nearby_buildings.as_json(
        only: [:id, :name, :address, :latitude, :longitude, :image_url, :analysis_result],
        methods: [:distance]
      )
    rescue => e
      Rails.logger.error "Nearby buildings error: #{e.message}"
      render json: { error: 'Internal server error' }, status: 500
    end

    def camera_upload
      uploaded_file = params[:image]
      address = params[:address]
      
      if uploaded_file.blank?
        render json: { error: 'Image file is required' }, status: 400
        return
      end

      begin
        # Extract EXIF GPS data if available
        gps_data = extract_gps_from_image(uploaded_file)
        
        # Create BuildingAnalysis record
        building_analysis = BuildingAnalysis.new(
          address: address || 'Mobile Upload',
          user_id: current_user&.id || 1, # Default to system user if not logged in
          visible_in_library: current_user.present?, # Only visible if user is logged in
          latitude: gps_data[:lat],
          longitude: gps_data[:lng]
        )

        if building_analysis.save(validate: false)
          # Upload to S3
          s3_url = upload_to_s3(uploaded_file, building_analysis.id)
          building_analysis.update_column(:image_url, s3_url)
          
          # Queue AI analysis
          ProcessBuildingAnalysisJob.perform_later(building_analysis.id, s3_url, address) if s3_url.present?
          
          render json: {
            id: building_analysis.id,
            image_url: s3_url,
            gps_extracted: gps_data[:extracted],
            latitude: gps_data[:lat],
            longitude: gps_data[:lng],
            status: 'uploaded',
            analysis_url: "/architecture_explorer/#{building_analysis.id}"
          }
        else
          render json: { error: 'Failed to save building analysis' }, status: 422
        end

      rescue => e
        Rails.logger.error "Camera upload error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: 'Upload failed' }, status: 500
      end
    end

    private

    def extract_gps_from_image(uploaded_file)
      return { extracted: false, lat: nil, lng: nil } unless uploaded_file.respond_to?(:tempfile)
      
      begin
        # Use exiftool command line tool if available (commonly installed)
        result = `exiftool -GPSLatitude -GPSLongitude -n #{uploaded_file.tempfile.path} 2>/dev/null`
        
        if $?.success? && result.present?
          lines = result.strip.split("\n")
          lat_line = lines.find { |line| line.include?('GPS Latitude') }
          lng_line = lines.find { |line| line.include?('GPS Longitude') }
          
          if lat_line && lng_line
            lat = lat_line.split(':').last.strip.to_f
            lng = lng_line.split(':').last.strip.to_f
            
            if lat != 0.0 && lng != 0.0
              return { extracted: true, lat: lat, lng: lng }
            end
          end
        end
        
        { extracted: false, lat: nil, lng: nil }
      rescue => e
        Rails.logger.warn "EXIF GPS extraction failed: #{e.message}"
        { extracted: false, lat: nil, lng: nil }
      end
    end

    def upload_to_s3(uploaded_file, building_id)
      return nil unless uploaded_file.present?
      
      require 'aws-sdk-s3'
      
      s3 = Aws::S3::Resource.new(region: 'us-east-2')
      bucket = s3.bucket('architecture-explorer')
      
      # Generate unique filename
      timestamp = Time.now.to_i
      key = "uploads/mobile_#{building_id}_#{timestamp}.jpg"
      
      # Upload file
      obj = bucket.object(key)
      obj.upload_file(uploaded_file.tempfile.path, content_type: 'image/jpeg')
      
      obj.public_url
    rescue => e
      Rails.logger.error "S3 upload error: #{e.message}"
      nil
    end
  end
end
