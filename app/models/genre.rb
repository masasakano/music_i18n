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
  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown
  include ModuleWeight  # adds a validation

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  #TRANSLATION_UNIQUE_SCOPES = :default

  has_many :musics,  dependent: :restrict_with_exception

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = UnknownGenre = {
    "ja" => 'ジャンル不明',
    "en" => 'UnknownGenre',
    "fr" => 'GenreInconnu',
  }.with_indifferent_access

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @return [Genre]
  def self.default(context=nil, place: nil)
    @genre_default ||= Genre.all.order(Arel.sql('CASE WHEN genres.weight IS NULL THEN 1 ELSE 0 END, genres.weight')).first  # NULLS LAST (in PostgreSQL)
  end

  # Returns true if self is one of the unknown genre
  def default?(context=nil, place: nil)
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
