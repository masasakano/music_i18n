# coding: utf-8
# == Schema Information
#
# Table name: domain_titles
#
#  id                                         :bigint           not null, primary key
#  memo_editor(Internal-use memo for Editors) :text
#  note                                       :text
#  weight(weight to sort this model index)    :float
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  site_category_id                           :bigint           not null
#
# Indexes
#
#  index_domain_titles_on_site_category_id  (site_category_id)
#  index_domain_titles_on_weight            (weight)
#
# Foreign Keys
#
#  fk_rails_...  (site_category_id => site_categories.id)
#
class DomainTitle < BaseWithTranslation
  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

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
  # This is disabled because the callback is defined below, although it is not
  # quite sufficient...  See unit model tests for what is desirable.
  # TODO: update
  TRANSLATION_UNIQUE_SCOPES = :disable

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  # Basically, Translations must be unique.
  #
  # @note This is not sufficient for DomainTitle (and the routine is obsolete anyway), but I leave it for now.
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    validate_translation_unique_title_alt(record)  # defined in BaseWithTranslation
  end

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['example.com', "ダミー"],
    "en" => ['example.com', "Dummy"],
    "fr" => ['example.com', "Factice"],
  }.with_indifferent_access

  belongs_to :site_category
  has_many :domains, dependent: :destroy  # cascade in DB. But this should be checked in Rails controller level!
#  has_many :uris,    dependent: :restrict_with_exception  # Exception in DB, too.

  validates_numericality_of :weight, allow_nil: true
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
