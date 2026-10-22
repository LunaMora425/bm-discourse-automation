# frozen_string_literal: true

module ::BmTitlePairingMatcher
  SEPARATOR = '\s*(?:x|×|4|/{1,2}|\\\\)\s*'

  def self.pairs_from_tag_names(names)
    names.filter_map do |name|
      match = name.to_s.match(/\A([a-z]+)x([a-z]+)\z/i)
      [match[1].downcase, match[2].downcase] if match
    end.uniq
  end

  def self.find(title, pairs, slash_words = [])
    return [] if pairs.empty?

    text = title.to_s.unicode_normalize(:nfkc)
    tokens = pairs.flatten.uniq.sort_by { |t| -t.length }
    token_alt = tokens.map { |t| Regexp.escape(t) }.join("|")
    found = []

    pair_regex = /(?<![[:alpha:]])(#{token_alt})#{SEPARATOR}(#{token_alt})(?![[:alpha:]])/i
    text.scan(pair_regex) do
      m = Regexp.last_match
      pair = [m[1].downcase, m[2].downcase]
      found << { text: m[0].strip, key: pair.join("x") } if pairs.include?(pair)
    end

    slash_alt = (tokens + slash_words.map(&:downcase)).uniq.map { |t| Regexp.escape(t) }.join("|")
    slash_regex = %r{(?<![[:alpha:]])(#{slash_alt})//(?![[:alpha:]/])}i
    text.scan(slash_regex) do
      m = Regexp.last_match
      found << { text: m[0], key: "#{m[1].downcase}//" }
    end

    found.uniq { |f| f[:key] }
  end
end
