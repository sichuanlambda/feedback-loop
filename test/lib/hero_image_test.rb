require "test_helper"

class HeroImageTest < ActiveSupport::TestCase
  def post(title, description = "A guide.")
    BlogPost.new(title: title, description: description)
  end

  test "prompt names the subject and forbids people" do
    prompt = HeroImage.prompt(post("David Winter Cottages", "Collectible miniature cottage sculptures."))
    assert_includes prompt, 'titled "David Winter Cottages"'
    assert_includes prompt, "Subject: Collectible miniature cottage sculptures."
    assert_includes prompt, "No people, no faces"
    refute_includes prompt, "side by side"
  end

  test "comparison posts ask for every subject in one frame" do
    prompt = HeroImage.prompt(post("Doric, Ionic, and Corinthian: How the Greek and Roman Orders Differ"))
    assert_includes prompt, "side by side in one frame"
    assert_includes prompt, "Doric, Ionic, and Corinthian."
    assert_includes HeroImage.prompt(post("Craftsman vs. Prairie Style: How to Tell Them Apart")), "Craftsman vs. Prairie Style."
  end

  test "extra style text is appended" do
    assert HeroImage.prompt(post("Tiny Homes"), style: "overcast winter light").end_with?("overcast winter light")
  end

  test "compress turns a large PNG into a smaller JPEG no wider than 1536px" do
    png = MiniMagick::Tool::Convert.new do |c|
      c.size "1800x1200"
      c << "plasma:fractal"
      c << "png:-"
    end
    jpeg = HeroImage.compress(png)
    assert_equal "\xFF\xD8".b, jpeg.byteslice(0, 2), "not a JPEG"
    assert_operator jpeg.bytesize, :<, png.bytesize
    assert_equal 1536, MiniMagick::Image.read(jpeg).width
  end
end
