# Prompt and post-processing for blog hero images (see rake blog:generate_heroes).
#
# The first prompts used only the post title, which produced a column post with
# no Doric column and a portrait of an invented man for a post about a real
# artist. The prompt now names the subject from the description, spells out
# comparison posts, and forbids people. Generated PNGs (2-3 MB) are shrunk to
# JPEG before upload because the hero is the largest image on a phone screen.
class HeroImage
  MAX_WIDTH = 1536
  JPEG_QUALITY = 82

  def self.prompt(post, style: nil)
    lines = []
    lines << "Editorial hero photograph for an architecture article titled \"#{post.title}\"."
    lines << "Subject: #{post.description}" if post.description.present?
    if (subjects = comparison_subjects(post.title))
      lines << "Show each of these side by side in one frame, clearly and accurately, " \
               "with the defining features of each visible: #{subjects}."
    end
    lines << "Photorealistic, natural light, magazine quality, architecture as the sole subject."
    lines << "No people, no faces, no hands, no text, no lettering, no watermarks, no borders, no logos."
    lines << style.to_s.strip if style.present?
    lines.join(' ')
  end

  # "Doric, Ionic, and Corinthian: How..." -> "Doric, Ionic, and Corinthian"
  # "Craftsman vs. Prairie Style: How..."  -> "Craftsman vs. Prairie Style"
  def self.comparison_subjects(title)
    head = title.to_s.split(':').first.to_s.strip
    return head if head.match?(/\bvs\.?\b/i) || head.count(',') >= 1
    nil
  end

  def self.compress(png_bytes)
    image = MiniMagick::Image.read(png_bytes)
    image.format('jpg')
    image.combine_options do |c|
      c.resize "#{MAX_WIDTH}x>"
      c.quality JPEG_QUALITY.to_s
      c.strip
      c.interlace 'JPEG'
    end
    image.to_blob
  end
end
