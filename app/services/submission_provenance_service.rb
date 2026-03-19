class SubmissionProvenanceService
  PROVENANCE_TYPES = {
    'manual_upload' => {
      name: 'Manual Upload',
      description: 'Uploaded directly by user',
      icon: '📤',
      color: '#007bff'
    },
    'bulk_import' => {
      name: 'Bulk Import',
      description: 'Imported in batch by admin',
      icon: '📦',
      color: '#6f42c1'
    },
    'api_submission' => {
      name: 'API Submission',
      description: 'Submitted via API',
      icon: '🔗',
      color: '#20c997'
    },
    'community_contribution' => {
      name: 'Community Contribution',
      description: 'Shared by community member',
      icon: '👥',
      color: '#fd7e14'
    },
    'research_dataset' => {
      name: 'Research Dataset',
      description: 'From architectural research',
      icon: '🏛️',
      color: '#6c757d'
    },
    'tourism_import' => {
      name: 'Tourism Import',
      description: 'From tourism database',
      icon: '🗺️',
      color: '#e83e8c'
    }
  }.freeze

  def self.add_provenance_to_building(building_analysis, provenance_type, metadata = {})
    return false unless PROVENANCE_TYPES.key?(provenance_type.to_s)

    provenance_data = {
      type: provenance_type.to_s,
      timestamp: Time.current.iso8601,
      metadata: metadata
    }

    # Add to existing provenance or create new
    existing_provenance = building_analysis.provenance_data || []
    existing_provenance << provenance_data

    building_analysis.update_column(:provenance_data, existing_provenance.to_json)
  end

  def self.get_building_provenance(building_analysis)
    return [] unless building_analysis.provenance_data.present?

    begin
      provenance_list = JSON.parse(building_analysis.provenance_data)
      provenance_list.map { |p| format_provenance_entry(p) }
    rescue JSON::ParserError
      []
    end
  end

  def self.get_provenance_summary(building_analysis)
    provenance_entries = get_building_provenance(building_analysis)
    return nil if provenance_entries.empty?

    # Get the primary (most recent or most significant) provenance
    primary_entry = provenance_entries.last
    
    {
      primary_type: primary_entry[:type],
      primary_name: primary_entry[:name],
      primary_icon: primary_entry[:icon],
      primary_color: primary_entry[:color],
      total_entries: provenance_entries.length,
      timestamp: primary_entry[:timestamp],
      description: primary_entry[:description]
    }
  end

  def self.get_user_submission_stats(user)
    user_buildings = user.building_analyses.includes(:building_analyses)
    stats = {}

    PROVENANCE_TYPES.each_key do |type|
      count = user_buildings.select do |building|
        provenance = get_building_provenance(building)
        provenance.any? { |p| p[:type] == type }
      end.length

      stats[type] = count if count > 0
    end

    {
      total_submissions: user_buildings.count,
      by_type: stats,
      most_common_type: stats.max_by { |k, v| v }&.first
    }
  end

  def self.add_submission_metadata(building_analysis, submission_context)
    metadata = {}

    # Add context-specific metadata
    case submission_context[:method]
    when 'manual_upload'
      metadata[:user_agent] = submission_context[:user_agent] if submission_context[:user_agent]
      metadata[:upload_source] = submission_context[:source] || 'web_form'
      metadata[:file_size] = submission_context[:file_size] if submission_context[:file_size]
      
    when 'bulk_import'
      metadata[:batch_id] = submission_context[:batch_id] if submission_context[:batch_id]
      metadata[:import_source] = submission_context[:import_source]
      metadata[:total_batch_size] = submission_context[:total_batch_size]
      
    when 'api_submission'
      metadata[:api_key] = submission_context[:api_key] if submission_context[:api_key]
      metadata[:endpoint] = submission_context[:endpoint]
      metadata[:client_version] = submission_context[:client_version]
    end

    # Add location context if available
    if submission_context[:location]
      metadata[:submitted_from] = {
        city: submission_context[:location][:city],
        country: submission_context[:location][:country],
        timezone: submission_context[:location][:timezone]
      }
    end

    metadata[:ip_hash] = Digest::SHA256.hexdigest(submission_context[:ip])[0..8] if submission_context[:ip]

    add_provenance_to_building(
      building_analysis,
      submission_context[:method],
      metadata
    )
  end

  def self.generate_provenance_badge_html(building_analysis)
    summary = get_provenance_summary(building_analysis)
    return '' unless summary

    <<~HTML
      <div class="provenance-badge" style="
        display: inline-flex;
        align-items: center;
        gap: 6px;
        background: #{summary[:primary_color]}15;
        color: #{summary[:primary_color]};
        border: 1px solid #{summary[:primary_color]}40;
        border-radius: 12px;
        padding: 4px 8px;
        font-size: 12px;
        font-weight: 500;
        margin: 0 4px 4px 0;
      ">
        <span style="font-size: 14px;">#{summary[:primary_icon]}</span>
        <span>#{summary[:primary_name]}</span>
        #{summary[:total_entries] > 1 ? "<span style='opacity: 0.7;'>+#{summary[:total_entries] - 1}</span>" : ''}
      </div>
    HTML
  end

  def self.detect_submission_method(params, request)
    # Auto-detect submission method based on context
    if request.user_agent&.include?('API') || params[:api_key].present?
      'api_submission'
    elsif params[:bulk_import] == 'true' || params[:batch_id].present?
      'bulk_import'
    elsif params[:community_share] == 'true'
      'community_contribution'
    else
      'manual_upload'
    end
  end

  # Migration helper to backfill existing buildings
  def self.backfill_existing_buildings
    BuildingAnalysis.find_in_batches(batch_size: 100) do |batch|
      batch.each do |building|
        next if building.provenance_data.present?

        # Determine likely provenance based on existing data
        provenance_type = if building.user_id == 880 # Atlas admin
          'research_dataset'
        elsif building.created_at < 1.month.ago
          'bulk_import'
        else
          'manual_upload'
        end

        metadata = {
          backfilled: true,
          inferred_from: 'creation_date_and_user',
          original_created_at: building.created_at.iso8601
        }

        add_provenance_to_building(building, provenance_type, metadata)
      end
    end
  end

  private

  def self.format_provenance_entry(entry)
    type_config = PROVENANCE_TYPES[entry['type']] || PROVENANCE_TYPES['manual_upload']
    
    {
      type: entry['type'],
      name: type_config[:name],
      description: type_config[:description],
      icon: type_config[:icon],
      color: type_config[:color],
      timestamp: entry['timestamp'],
      metadata: entry['metadata'] || {}
    }
  end
end