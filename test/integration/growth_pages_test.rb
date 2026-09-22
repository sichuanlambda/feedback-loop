require "test_helper"

# Covers the mobile / conversion / SEO / bot-handling changes end to end.
class GrowthPagesTest < ActionDispatch::IntegrationTest
  IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1".freeze
  CLAUDEBOT = "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ClaudeBot/1.0; +claudebot@anthropic.com)".freeze

  def browse(path, agent: IPHONE)
    get path, headers: { "User-Agent" => agent }
  end

  test "unnamed building page gets a descriptive title and an eager photo above the analysis" do
    building = building_analyses(:two)
    browse architecture_explorer_show_path(building)

    assert_response :success
    assert_select "title", "Art Deco & Gothic Revival Building in Chicago — Architecture Analysis | Architecture Helper"
    assert_select "meta[name=description][content*='Art Deco']"
    assert_select ".hero-image img[fetchpriority=high]:not([loading])"
    assert_operator response.body.index('class="hero-image"'), :<, response.body.index('class="legacy-content"')
    refute_match(/order: 2; \} \/\* Image second on mobile/, response.body)
  end

  test "people are tracked, crawlers are not" do
    assert_difference -> { UserEvent.where(event_type: "page_view").count }, 1 do
      browse pricing_path
    end
    assert_no_difference -> { UserEvent.count } do
      browse pricing_path, agent: CLAUDEBOT
      browse architecture_explorer_show_path(building_analyses(:one)), agent: CLAUDEBOT
    end
  end

  test "view gate still meters people but never blurs pages for crawlers" do
    gate_buildings = Array.new(4) do |i|
      BuildingAnalysis.create!(user: users(:one), name: "Gate #{i}", html_content: "<h3>Art Deco</h3><p>x</p>", visible_in_library: true)
    end

    gate_buildings.each { |b| browse architecture_explorer_show_path(b) }
    assert_includes response.body, "Unlock Full Analysis"

    reset!
    gate_buildings.each { |b| browse architecture_explorer_show_path(b), agent: CLAUDEBOT }
    refute_includes response.body, "Unlock Full Analysis"
  end

  test "upload form leads with the camera on phones and explains the payoff" do
    browse architecture_explorer_new_path

    assert_response :success
    assert_select "button[data-upload-pick=camera]", text: /Take a Photo/
    assert_select "input[type=file][accept='image/*']"
    assert_select "input[type=submit][value='Analyze This Building'][disabled]"
    assert_select ".upload-benefits li", 3
    assert_select "a", text: /See an example analysis/
  end

  test "email signup lands on the upload form with the free credit called out" do
    post user_registration_path, params: { user: {
      email: "new@example.com", password: "password123", password_confirmation: "password123", terms_of_service: "1"
    } }, headers: { "User-Agent" => IPHONE }

    assert_redirected_to architecture_explorer_new_path(src: "post_signup")
    follow_redirect! headers: { "User-Agent" => IPHONE }
    assert_includes response.body, "your account is ready"
    assert_includes response.body, "1 free credit"
  end

  test "signup page sizes the logo by width and has a real title" do
    browse new_user_registration_path

    assert_response :success
    assert_select "title", "Create a Free Account | Architecture Helper"
    assert_select "img.signup-logo[width='50']"
    assert_select "input#user_email:not([autofocus])"
  end

  test "pricing and library pages render with their mobile rules" do
    browse pricing_path
    assert_response :success
    assert_includes response.body, ".plan-card.free { order: 3; }"

    browse "/building_library"
    assert_response :success
    assert_select "title", /Building Library/
    assert_select ".d-none.d-md-block h2", text: "Discover and Generate Architecture"
  end
end
