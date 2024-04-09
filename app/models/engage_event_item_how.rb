# coding: utf-8

# == Schema Information
#
# Table name: engage_event_item_hows
#
#  id                                                  :bigint           not null, primary key
#  mname(unique machine name)                          :string           not null
#  note                                                :text
#  weight(weight to sort entries in Index for Editors) :float            default(999.0), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
# Indexes
#
#  index_engage_event_item_hows_on_mname   (mname) UNIQUE
#  index_engage_event_item_hows_on_weight  (weight)
#
class EngageEventItemHow < BaseWithTranslation
  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  #has_many :engages,     dependent: :restrict_with_exception
  #has_many :event_items, dependent: :restrict_with_exception

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

  validates_presence_of   :mname
  validates_uniqueness_of :mname
  validates_presence_of   :weight  # NOTE: At the DB level, a default is defined.
  validates_uniqueness_of :weight  # No DB-level constraint, but this is checked at Rails-level.

  UNKNOWN_TITLES = UnknownEngageEventItemHow = {
    "ja" => ['イベント項目関与形態不明', '関与形態不明'],
    "en" => ['Unknown Engage-EventItem relation', 'Unknown relation'],
    "fr" => ['Relation inconnue entre Engage-EventItem', 'Relation inconnue'],
  }.with_indifferent_access

  # @return [EngageHow]
  def self.unknown
    @engage_unknown ||= self[UNKNOWN_TITLES['en'].first, 'en']
  end

  def unknown?
    self == self.class.unknown
  end

end
