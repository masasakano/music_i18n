# coding: utf-8

# == Schema Information
#
# Table name: instruments
#
#  id                                    :bigint           not null, primary key
#  note                                  :text
#  weight(weight for sorting for index.) :float            default(999.0), not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#
# Indexes
#
#  index_instruments_on_weight  (weight)
#
class Instrument < BaseWithTranslation
  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  ## Commented out because this contradicts:   not null
  # include ModuleWeight  # adds a validation

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

  has_many :artist_music_plays, dependent: :restrict_with_exception  # dependent is a key / Basically PlayRole should not be easily destroyed - it may be merged instead.
  %i(event_items artists musics play_roles).each do |esym|
    has_many esym, -> {distinct}, through: :artist_music_plays
  end

  validates_presence_of   :weight  # NOTE: At the DB level, a default is defined.
  validates_uniqueness_of :weight  # No DB-level constraint, but this is checked at Rails-level.
  validates_numericality_of :weight
  validates :weight, :numericality => { :greater_than_or_equal_to => 0 }

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = UnknownInstrument = {
    "ja" => ['不明の楽器'],
    "en" => ['Unknown music instrument', 'Unknown instrument'],
    "fr" => ['Instrument inconnu'],
  }.with_indifferent_access

  # Returning a default Instrument in the given context
  #
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @return [EventItem, Event]
  def self.default(context=nil, place: nil)
    case context.to_s.underscore.singularize
    when *(%w(harami_vid harami1129))
      ret = (self.select_regex(:title, /^piano$/i, langcode: "en", sql_regexp: true).first ||
             self.select_regex(:title, /^ピアノ/i, langcode: "ja", sql_regexp: true).first ||
             self.select_regex(:title, /ピアノ|piano/i, sql_regexp: true).first)
      return ret if ret
      logger.warn("WARNING(#{File.basename __FILE__}:#{__method__}): Failed to identify the default Instrument!")
    end

    self.unknown
  end
end
