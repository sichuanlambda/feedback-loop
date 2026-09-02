# Normalizes AI-written copy before it is stored. The models keep reaching
# for em dashes no matter what the prompt says, and the site's copy rules
# forbid them, so fix it in code rather than in the prompt.
module GeneratedCopy
  def self.clean(text)
    return text if text.blank?
    text.to_s
        .gsub(/(\d)\s*[—–]\s*(\d)/, '\1-\2')   # 1920—1930 -> 1920-1930
        .gsub(/\s*[—–]\s*/, ', ')              # clause dashes -> comma
        .gsub(/\s*,\s*,/, ',')                 # no doubled commas
  end

  def self.clean_faq(faq)
    Array(faq).map do |f|
      { 'question' => clean(f['question'].to_s.strip), 'answer' => clean(f['answer'].to_s.strip) }
    end.reject { |f| f['question'].blank? || f['answer'].blank? }
  end
end
