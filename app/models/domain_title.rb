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
  extend ModuleCommon  # for guess_lang_code

  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown
  include ModuleWeight  # adds a validation

  include ModuleWasFound # defines attr_writers @was_found, @was_created and their questioned-readers. (4 methods)

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
  has_many :urls, through: :domains       # This prohibits cascade destroys - you must destroy all Urls first.

  # An alternative constructor (unsaved, but ready to be saved)
  #
  # @param url_str [String]
  # @param site_category_id: [NilClass, String, Integer] "" would raise an error.  If nil, Default is used.
  # @return [DomainTitle]
  def self.new_from_url(url_str, site_category_id: nil)
    ret = DomainTitle.new(site_category_id: (site_category_id || SiteCategory.default&.id))&.tap(&:set_was_created_true)  # A fallback is unknown
    if !ret.site_category_id
      raise HaramiMusicI18n::InconsistentDataIntegrityError, "Strangely, SiteCategory.default is undefined. Run seeding on SiteCategory"
    end
    domain_txt = Addressable::URI.unencode(Domain.extracted_normalized_domain(url_str, with_www: false))  # without "www."
    ret.unsaved_translations << Translation.new(title: domain_txt, langcode: guess_lang_code(domain_txt), is_orig: nil, weight: Float::INFINITY)
    ret
  end

  # @param urs_str: [String] any URL-type String
  # @return [DomainTitle, NilClass]
  def self.find_by_urlstr(url_str)
    dom = Domain.find_by_both_urls(url_str) #, is_normalized_no_www: false)
    dom.domain_title&.tap(&:set_was_found_true) if dom
  end

  # Returns the highest-priority Domain
  #
  # @return [Domain, NilClass] nil only in an unlikely case of no child Domains.
  def primary_domain
    domains.order(:weight).first
  end

  # At the association level (NOT the user-permission level)
  def destroyable?
    !urls.exists?
  end
end


class << DomainTitle
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, site_category: nil, site_category_id: nil, **kwds, &blok)
    site_category_id ||= (site_category ? site_category.id : (SiteCategory.unknown || SiteCategory.create_basic!(*args)).id)
    create_basic_bwt!(*args, site_category_id: site_category_id, **kwds, &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  def initialize_basic(*args, site_category: nil, site_category_id: nil, **kwds, &blok)
    site_category_id ||= (site_category ? site_category.id : (SiteCategory.unknown || SiteCategory.first).id)
    initialize_basic_bwt(*args, site_category_id: site_category_id, **kwds, &blok)
  end
end

