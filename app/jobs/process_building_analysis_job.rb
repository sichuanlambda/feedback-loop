class ProcessBuildingAnalysisJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(building_analysis_id, image_url, address)
    building_analysis = BuildingAnalysis.find_by(id: building_analysis_id)
    unless building_analysis
      Rails.logger.warn "[ProcessBuildingAnalysisJob] BuildingAnalysis ##{building_analysis_id} not found, skipping."
      return
    end

    Rails.logger.info "[ProcessBuildingAnalysisJob] Starting analysis for BuildingAnalysis ##{building_analysis_id}"

    gpt_response = GptService.new.send_building_analysis(image_url)

    # An image with no building in it (a street of trees, a blurry sky) comes
    # back shaped like a response but with no styles. Writing that would fill
    # the page with a stringified hash, which is worse than leaving it unset.
    if gpt_response.is_a?(Hash) && gpt_response.key?("styles") && Array(gpt_response["styles"]).empty?
      Rails.logger.error "[ProcessBuildingAnalysisJob] No styles identified for BuildingAnalysis ##{building_analysis_id} — not writing content"
      raise "No architectural styles identified for BuildingAnalysis ##{building_analysis_id}"
    end

    if gpt_response.present?
      if gpt_response.is_a?(Hash) && gpt_response.key?("styles")
        # Normalize style names through StyleNormalizer (single source of truth)
        raw_style_names = gpt_response["styles"].map { |s| s["name"] }
        normalized_names = StyleNormalizer.normalize_array(raw_style_names)

        # Update the style names in the response to canonical forms
        gpt_response["styles"].each do |style_hash|
          style_hash["name"] = StyleNormalizer.normalize(style_hash["name"]) || style_hash["name"]
        end

        # Deduplicate styles that normalized to the same canonical name
        # Keep the one with highest confidence
        seen = {}
        gpt_response["styles"] = gpt_response["styles"].select do |style_hash|
          name = style_hash["name"]
          if seen[name]
            false
          else
            seen[name] = true
            true
          end
        end

        normalized_names = gpt_response["styles"].map { |s| s["name"] }

        # Update building name if we got one and the record doesn't have one.
        # The model sometimes echoes the prompt's own placeholder wording back
        # ("Descriptive name", "null") — that must not become a page title.
        gpt_name = gpt_response["building_name"].to_s.strip
        gpt_name = nil if gpt_name.match?(/\A(null|n\/a|none|descriptive name.*|name if recognizable.*)\z/i)
        if building_analysis.name.blank? && gpt_name.present?
          building_analysis.update_column(:name, gpt_name)
        end

        building_analysis.update!(
          html_content: gpt_response.to_json,
          h3_contents: normalized_names.to_json
        )
      else
        # Legacy format fallback
        html_content = gpt_response["analysis"] || gpt_response.to_s
        html_content = CGI.unescapeHTML(html_content)
        cleaned_html_content = remove_code_block_markers(html_content)
        h3_contents = extract_h3s(cleaned_html_content)

        # Normalize legacy styles too
        h3_contents = StyleNormalizer.normalize_array(h3_contents)

        building_analysis.update!(html_content: cleaned_html_content, h3_contents: h3_contents.to_json)
      end

      Rails.logger.info "[ProcessBuildingAnalysisJob] Completed analysis for BuildingAnalysis ##{building_analysis_id}"
    else
      Rails.logger.error "[ProcessBuildingAnalysisJob] GPT returned empty response for BuildingAnalysis ##{building_analysis_id}"
      raise "GPT returned empty response for BuildingAnalysis ##{building_analysis_id}"
    end
  end

  private

  def remove_code_block_markers(html_content)
    html_content.gsub(/^\s*```html\s*\r?\n/, "").gsub(/\r?\n\s*```\s*$/, "")
  end

  def extract_h3s(html_content)
    doc = Nokogiri::HTML(html_content)
    doc.search('h3').map do |h3|
      h3.text.gsub(/[^\w\s]/, '').gsub(/\d/, '').strip
    end.uniq
  end
end
