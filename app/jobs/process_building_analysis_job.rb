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

    if gpt_response.present?
      # New structured JSON response from GPT
      if gpt_response.is_a?(Hash) && gpt_response.key?("styles")
        # Store the structured JSON as html_content
        structured_json = gpt_response.to_json
        # Extract style names for h3_contents
        style_names = gpt_response["styles"].map { |s| s["name"] }

        building_analysis.update!(
          html_content: structured_json,
          h3_contents: style_names.to_json
        )
      else
        # Legacy format fallback (in case old response format)
        html_content = gpt_response["analysis"] || gpt_response.to_s
        html_content = CGI.unescapeHTML(html_content)
        cleaned_html_content = remove_code_block_markers(html_content)
        h3_contents = extract_h3s(cleaned_html_content)

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
