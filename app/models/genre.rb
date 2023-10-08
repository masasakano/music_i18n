# coding: utf-8
# == Schema Information
#
# Table name: genres
#
#  id                                        :bigint           not null, primary key
#  note                                      :text
#  weight(Smaller means higher in priority.) :float
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#
class Genre < BaseWithTranslation
  include Translatable

  has_many :musics,  dependent: :restrict_with_exception

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" from "The Beatles".  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  UnknownGenre = {
    "ja" => 'ジャンル不明',
    "en" => 'UnknownGenre',
    "fr" => 'GenreInconnu',
  }

  # Returns the unknown {Genre}
  #
  # @return [Genre]
  def self.unknown
    @genre_unknown ||= self[UnknownGenre['en'], 'en']
  end

  # Returns true if self is one of the unknown genre
  def unknown?
    title(langcode: 'en') == UnknownGenre['en']
  end

  # Returns the default {Genre}
  #
  # @return [Genre]
  def self.default
    @genre_default ||= Genre.all.order(Arel.sql('CASE WHEN genres.weight IS NULL THEN 1 ELSE 0 END, genres.weight')).first  # NULLS LAST (in PostgreSQL)
  end

  # Returns true if self is one of the unknown genre
  def default?
    self == self.class.default
  end

  # If allow_nil=true this returns false when other is nil.
  # Else, this returns true when other is nil.
  #
  # @param other [Genre]
  # @param allow_nil [Boolean] if nil, (nil, male) would return false.
  # @raise [TypeError] if other is non-nil and not Genre
  def not_disagree?(other, allow_nil: true)
    return allow_nil if other.nil?
    raise TypeError, "other is not Genre: #{other.inspect}" if !(Genre === other)
    return true if [self, other].any?(&:unknown?)
    self == other
  end
end
