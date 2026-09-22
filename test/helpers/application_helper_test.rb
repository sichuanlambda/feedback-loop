require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "splits a post body before its second h2" do
    top, rest = split_post_body_for_inline_cta("<p>intro</p><h2>One</h2><p>a</p><h2 id=\"two\">Two</h2><p>b</p>")
    assert_equal "<p>intro</p><h2>One</h2><p>a</p>", top
    assert_equal "<h2 id=\"two\">Two</h2><p>b</p>", rest
  end

  test "leaves short posts whole" do
    top, rest = split_post_body_for_inline_cta("<p>intro</p><h2>Only</h2><p>a</p>")
    assert_equal "<p>intro</p><h2>Only</h2><p>a</p>", top
    assert_nil rest
    assert_equal ["", nil], split_post_body_for_inline_cta(nil)
  end
end
