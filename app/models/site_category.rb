# coding: utf-8
# == Schema Information
#
# Table name: site_categories
#
#  id                                         :bigint           not null, primary key
#  mname(Unique machine name)                 :string           not null
#  note                                       :text
#  memo_editor(Internal-use memo for Editors) :text
#  summary(Short summary)                     :text
#  weight                                     :float
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#
# Indexes
#
#  index_site_categories_on_mname    (mname) UNIQUE
#  index_site_categories_on_summary  (summary)
#  index_site_categories_on_weight   (weight)
#
class SiteCategory < BaseWithTranslation
  include ApplicationHelper # for link_to_youtube
  include ModuleCommon # for convert_str_to_number_nil, set_singleton_method_val, SiteCategory.new_unique_max_weight etc.

  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = %i(mname)

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true  # because title is a sentence.

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  #TRANSLATION_UNIQUE_SCOPES = :default

  ## Validates translation immediately before it is added.
  ##
  ## Called by a validation in {Translation}
  ##
  ## Basically, Translations must be unique.
  ##
  ## @param record [Translation]
  ## @return [Array] of Error messages, or empty Array if everything passes
  #def validate_translation_callback(record)
  #  validate_translation_neither_title_nor_alt_exist(record)  # defined in BaseWithTranslation
  #end

  #has_many :uris, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.  # NOTE: you may add(?) -> {distinct}

  validates_presence_of   :mname
  validates_uniqueness_of :mname
  validates_presence_of   :weight  # NOTE: At the DB level, no constraint (no default is defined...).
  #validates_uniqueness_of :weight  # No DB-level constraint, either
  validates_numericality_of :weight
  validates :weight, :numericality => { :greater_than_or_equal_to => 0 }

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のサイト種別'],
    "en" => ['Unknown site category'],
    "fr" => ['Type de site inconnu'],
  }.with_indifferent_access

  # Returning a default Model in the given context
  #
  # @option context [Symbol, String]
  # @return [EventItem, Event]
  def self.default(context=nil)
    #case context.to_s.underscore.singularize
    #when *(%w(harami_vid harami1129))
    #  ret = self.find_by(mname: "main")
    #  return ret if ret
    #  logger.warn("WARNING(#{File.basename __FILE__}:#{__method__}): Failed to identify the default #{self.class.name}!")
    #end

    self.unknown
  end

end



