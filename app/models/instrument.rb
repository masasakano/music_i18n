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

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = false

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  #
  # Basically, Translations must be unique.
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    validate_translation_neither_title_nor_alt_exist(record)  # defined in BaseWithTranslation
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

end