# Writes the intro + FAQ for one "<Style> Architecture in <City>" page,
# grounded in the buildings the page will actually list.
class StyleCityContentGenerator
  def initialize(style_name, city_name, buildings)
    @style_name = style_name
    @city_name = city_name
    @buildings = buildings
  end

  # Creates or refreshes the StyleCityPage row. Returns the record, or nil if
  # generation failed (no row is written on failure).
  def generate!
    result = GptService.new.chat_json(prompt, max_tokens: 2200)
    intro = result && result['intro_html'].to_s.strip
    faq = result && result['faq']
    return nil if intro.blank? || !faq.is_a?(Array) || faq.empty?

    page = StyleCityPage.find_or_initialize_by(style_name: @style_name, city_slug: @city_name.parameterize)
    page.assign_attributes(
      city_name: @city_name,
      intro_html: GeneratedCopy.clean(intro),
      faq: GeneratedCopy.clean_faq(faq.first(6)),
      building_count: @buildings.size,
      generated_at: Time.current
    )
    page.save!
    page
  end

  private

  def building_notes
    @buildings.first(18).map do |b|
      name = b.display_name || b.display_address.to_s.split(',').first
      note = "- #{name}"
      note += " (#{b.display_address})" if b.display_address.present? && b.display_address != name
      detail = style_detail_for(b)
      note += ": #{detail}" if detail.present?
      note
    end.join("\n")
  end

  # Pull the per-style description out of the stored analysis JSON so the
  # prompt is grounded in what the vision model actually saw.
  def style_detail_for(building)
    raw = building.html_content.to_s.strip
    return nil unless raw.start_with?('{')
    data = JSON.parse(raw)
    match = Array(data['styles']).detect { |s| StyleNormalizer.normalize(s['name']) == @style_name }
    (match && match['description'].presence) || data['overview'].presence&.truncate(220)
  rescue JSON::ParserError
    nil
  end

  def prompt
    <<~PROMPT
      You write for Architecture Helper, a site that documents real buildings by architectural style and city.

      Write the editorial content for the page "#{@style_name} Architecture in #{@city_name}".
      The page lists these #{@buildings.size} documented #{@style_name} buildings in #{@city_name}:
      #{building_notes}

      Return JSON with exactly these keys:
      {
        "intro_html": "3 to 4 paragraphs of HTML using only <p>, <strong> and <em> tags, 320 to 450 words total. Explain why #{@style_name} appears in #{@city_name}: the historical moment, the local economy or events that drove it, the materials and details that give the local version its character, and which neighbourhoods or streets concentrate it. Refer by name to at least three of the buildings listed above and say what is distinctive about each. Only the buildings in the list are documented on this page: do not present any other building as one of the documented examples. You may mention a well-known #{@style_name} landmark in #{@city_name} that is not in the list only if you say plainly that it is not yet in the library. Never invent architects, dates or addresses.",
        "faq": [ { "question": "...", "answer": "..." } ]
      }

      Rules for the FAQ: 4 or 5 questions a curious visitor or a search user would actually ask about #{@style_name} architecture in #{@city_name} (where to see it, when it was built, what to look for, how it compares to the style elsewhere, whether it can be visited). Answers are plain text, 40 to 80 words each, specific to #{@city_name}, grounded in the buildings above where possible.

      Style rules: confident, specific, no marketing fluff, no exclamation marks, never use em dashes, and avoid stock phrases such as "rich tapestry", "vibrant", "nestled", "testament to", "boasts" and "gem". Do not repeat the page title verbatim as a sentence.
    PROMPT
  end
end
