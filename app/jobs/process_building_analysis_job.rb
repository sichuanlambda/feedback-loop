class ProcessBuildingAnalysisJob < ApplicationJob
  queue_as :default

  def perform(building_analysis_id, image_url, address)
    building_analysis = BuildingAnalysis.find_by(id: building_analysis_id)
    return unless building_analysis

    # Assuming GptService is the service object that interacts with your GPT model for analysis
    gpt_response = GptService.new.send_building_analysis(image_url)

    if gpt_response.present?
      html_content = gpt_response["analysis"]
      html_content = CGI.unescapeHTML(html_content)
      cleaned_html_content = remove_code_block_markers(html_content)
      h3_contents = extract_h3s(cleaned_html_content)

      building_analysis.update(html_content: cleaned_html_content, h3_contents: h3_contents.to_json)
    else
      Rails.logger.error "GPT did not return a response for image analysis."
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
    end.uniq # Ensure no duplicates
  end
end
