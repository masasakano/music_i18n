# coding: utf-8
# == Schema Information
#
# Table name: urls
#
#  id                                              :bigint           not null, primary key
#  last_confirmed_date                             :date
#  memo_editor                                     :text
#  note                                            :text
#  published_date                                  :date
#  url(valid URL/URI including https://)           :string           not null
#  url_langcode(2-letter locale code)              :string
#  url_normalized(URL part excluding https://www.) :string
#  weight(weight to sort this model)               :float
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  create_user_id                                  :bigint
#  domain_id                                       :bigint           not null
#  update_user_id                                  :bigint
#
# Indexes
#
#  index_urls_on_create_user_id        (create_user_id)
#  index_urls_on_domain_id             (domain_id)
#  index_urls_on_last_confirmed_date   (last_confirmed_date)
#  index_urls_on_published_date        (published_date)
#  index_urls_on_update_user_id        (update_user_id)
#  index_urls_on_url                   (url)
#  index_urls_on_url_and_url_langcode  (url,url_langcode) UNIQUE
#  index_urls_on_url_langcode          (url_langcode)
#  index_urls_on_url_normalized        (url_normalized)
#  index_urls_on_weight                (weight)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (domain_id => domains.id)
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
class Url < BaseWithTranslation
  # handles create_user, update_user attributes
  include ModuleCreateUpdateUser

  extend ModuleCommon  # for contain_asian_char?

  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown
  include ModuleWeight  # adds a validation

  #include ModuleUrlUtil # self.class.normalized_url etc.  # Using it (in the class method with the same name) without including it.

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

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['example.com'],
    "en" => ['example.com'],
    "fr" => ['example.com'],
  }.with_indifferent_access

  # Callback
  before_validation :add_scheme_to_url
  before_validation :adjust_url_minimum  # trimming an unnecessary prefix slash(es), truncating multiple slashes at the tail
  before_validation :normalize_url
  before_validation :normalize_url_langcode

  belongs_to :domain

  has_one :domain_title, through: :domain
  has_one :site_category, through: :domain_title

  has_many :anchorings, dependent: :destroy
  ## Below, ChannelPlatform is not included because it should be related to DomainTitle. You should not include Translation here because Url already has_many Translation-s.
  %w(Artist Channel Event EventGroup HaramiVid Music Place).each do |em|
    has_many em.underscore.pluralize.to_sym, through: :anchorings, source: :anchorable, source_type: em
    # or surely(?) # has_many em.underscore.pluralize.to_sym, through: :anchorings, source: :anchorable, source_type: em
  end

  validates :url, presence: true
  validates :url,            uniqueness: {case_sensitive: false, scope: :url_langcode}
  validates :url_normalized, uniqueness: {case_sensitive: false}  # scheme, port, "www." do not matter. case-insensitive INCLUDING the path/query/fragment part. Empty query/fragment ignored.
  validate  :url_validity   # Should have a valid host with/without a scheme.
  validates :url_langcode, length: {is: 2}, format: {with: /\A[a-z]{2}\z/i}, allow_nil: true, allow_blank: true  # so far, "-" etc are not allowed.
  validates :last_confirmed_date, comparison: { greater_than_or_equal_to: :published_date }, allow_nil: true

  # Wrapper of ModuleUrlUtil.normalized_url with a specific combination of options
  #
  # excluding the scheme, "www.", and the trailing forward slash only IF the URL is just a domain part.
  # All the queries and fragments are preserved, except for Youtube, in which
  # the tracking queries are removed.
  #
  # @param url_in [String]
  # @return [String]
  def self.normalized_url(url_in)
    ModuleUrlUtil.normalized_url(
      url_in,
      with_scheme: false,
      with_www: false,
      with_port: false,
      trim_insignificant_prefix_slash: true,
      with_path: true,
      truncate_trailing_slashes: true,
      with_query: true,
      with_fragment: true,
      decode_all: true,
      downcase_domain: true)
  end

  # @return [String] as saved for the main attribute {#url}
  def self.minimum_adjusted_url(url_in)
    ModuleUrlUtil.normalized_url(
      url_in,
      with_scheme: true,
      with_www: true,
      with_port: true,
      trim_insignificant_prefix_slash: true,
      with_path: true,
      truncate_trailing_slashes: true,
      with_query: true,
      with_fragment: true,
      decode_all: false,
      downcase_domain: false,
      delegate_special: true)
  end

  # Returns the default Translation if the given title is blank
  #
  # @param url [String, Url]
  # @return [Translation] initialized and unsaved. {Translation#translatable} is unset.
  def self.def_translation_from_url(url, title: nil, langcode: nil, is_orig: nil, **kwds)
    urlstr = (url.respond_to?(:url) ? url.url : url.to_s)
    title = normalized_url(urlstr) if title.blank?  # URI.decode_www_form_component would fail in Domain with non-ASCII
    langcode = (contain_asian_char?(title) ? "ja" : "en") if langcode.blank?
    Translation.new(title: title, langcode: langcode, is_orig: is_orig, **kwds)
  end

  # Search and find a Url from String URL.
  #
  # Url is unique by {#url_normalized}
  #
  # @param urlstr [String] mandatory.
  # @return [Url, NilClass]
  def self.find_url_from_str(urlstr)
    find_by(url_normalized: normalized_url(urlstr))
  end

  # Alternative constructor from String URL
  #
  # {Url#url} is as the user (editor) specifies — no change or normalization, including case-sensitivity,
  # except that a null query or fragment is removed and multiple trailing slashes are
  # truncated to one as in before_validation.  And a scheme ("https://") is added if not present.
  #
  # @param urlstr [String] mandatory.
  # @param site_category_id: [NilClass, String, Integer] Used only in creating DomainTitle. ignored if nil. auto-guessed if "".  See {Domain.find_or_initialize_domain_title_to_assign} and {Domain.guess_site_category}
  # @param **kwds [Hash] You can initialize any of the standard attributes of Url, plus its Translation. All are optional, and can be automatically set.
  # @return [Url] In failing, +errors+ may be set or +id+ may be nil. +domain+ may be set and +domain.notice_messages+ may be significant (to show as flash messages).
  def self.create_url_from_str(urlstr, site_category_id: nil, url_langcode: nil, domain: nil, domain_id: nil, weight: nil, published_date: nil, last_confirmed_date: nil, note: nil, memo_editor: nil, title: nil, langcode: nil, is_orig: nil, alt_title: nil)
    newurl = self.new(url: urlstr,
                     url_langcode: url_langcode,
                     weight: weight,
                     published_date: published_date,
                     last_confirmed_date: last_confirmed_date,
                     note: note,
                     memo_editor: memo_editor)
    newurl.domain    = domain    if domain
    newurl.domain_id = domain_id if domain_id

    newurl.unsaved_translations << def_translation_from_url(newurl, title: title, langcode: langcode, is_orig: is_orig, alt_title: alt_title)

    ret = newurl.find_or_create_and_reset_domain_id(site_category_id: site_category_id)
    return newurl if !ret  # "newurl.errors" should have been set.  "newurl.id" is nil.

    newurl.save
    newurl  # In failing, "newurl.errors" should be set.  If successful, a Translation should have been also created.
  end

  # Returns an Array of old Child Anchoring records
  #
  # @return [Array<ActiveRecords>]
  def anchoring_parents
    anchorings.map(&:anchorable)
    #anchorings.map{|i| i.anchorable}  # NOTE: anchorings.map(&anchorable) would not work for some reason!!
  end

  # If {#domain_id} is blank, assign one according to url, potentially creating Domain (and maybe DomainTitle), and reset domain_id
  #
  # If {#domain_id} is non-blank, nothing is done and returns self in default unless +force+ is true.
  #
  # 1. If {#domain_id} is not blanck, this method does nothing and returns self.
  # 2. If Domain (and maybe also DomainTitle) is either successfully found or created,
  #    this method returns self (hence truthy).  +self.domain.notice_messages+
  #    contains 1 (if only a Domain is created) or 2 (if both are created) messages.
  #    The caller (Controller?) may use it, for flash messaging etc.
  # 3. If the creation of Domain or DomainTitle has failed, this method returns nil.
  #    +self.errors+ contains the error message.
  #
  # @note
  #   The caller should put the call of this method in a DB transaction because this method may save records in DB.
  #
  # @example  use of a transaction before saving.
  #    ActiveRecord::Base.transaction(requires_new: true) do
  #      if !find_or_create_and_reset_domain_id || !save
  #        raise ActiveRecord::Rollback, "Force rollback."
  #      end
  #    end
  #    # If rolled back,  self.domain_id  may point to a non-existing Domain.
  #
  # @param force [Boolean] If true (Def: false), {Domain} is reassigned (maybe created) even if self.domain is present.
  # @param site_category_id: [NilClass, String, Integer] Used only in creating DomainTitle. ignored if nil. auto-guessed if "".  See {Domain.find_or_initialize_domain_title_to_assign} and {Domain.guess_site_category}
  # @return [Url, NilClass] self or nil (if an error happens in creating Domain or DomainTitle)
  def find_or_create_and_reset_domain_id(force: false, site_category_id: nil)
    return self if !domain_id.blank? && !force

    begin
      self.domain = Domain.find_or_create_domain_by_url!(url, site_category_id: site_category_id)
    rescue Domains::CascadeSaveError => err
      errors.add :domain_id, err.message
      return  # an error happens.
    end

    self
  end

  # Resets Domain if self's {#domain} has changed (but not saved) in default.
  #
  # self is not saved, but Domain (and DomainTite) may be created.
  # If Domain (or DomainTite) was attempted to be created but if it has failed,
  # self.errors is set.
  #
  # self.domain.notice_messages should be significant after this call
  # if a Domain is searched for (namely, if self.url has not changed in the first place, the message is not defined).
  #
  # In default, if the the unsaved {#url} has not changed from the DB value,
  # this method does nothing, providing +site_category_id+ is nil or +force+ is true.
  #
  # If site_category_id is nil, this method does not alter the associattion to SiteCategory.
  # If it is significant, this method changes the associated {DomainTitle#site_category_id}.
  # And also (**IMPORTANT**), if it is an empty String (""), this resets the associated {DomainTitle#site_category_id}
  # to a new value(!!) because the selection must have been altered delibrerately in the form.
  # Note that if site_category_id is non-nil, new Domain and DomainTitle may be created
  # even if {#url} is unchanged, because {Domain#domain} is reassessed.  With an inline-U/I,
  # such a discrepancy should have never happened anyway, though it can happen through
  # the dedicated Url-edit U/I.
  #
  # @param force: [Boolean] Def: false
  # @param site_category_id: [NilClass, String, Integer] no change if nil. auto-guessed if "".  See {Domain.find_or_initialize_domain_title_to_assign} and {Domain.guess_site_category}
  # @return [Boolean] true if updated.  nil if an unlikely case of url being blank?
  def reset_assoc_domain(force: false, site_category_id: nil)
    return if url.blank?
    return self.domain if !force && !url_changed? && (site_category_id.nil? || site_category_id.to_s.strip == domain_title.site_category_id.to_s)
    domain_title_bkup = self.domain_title
    domain_bkup       = self.domain

    find_or_create_and_reset_domain_id(force: force, site_category_id: site_category_id)  # maybe a created one.

    self.domain != domain_bkup || self.domain_title != domain_title_bkup
  end

  private

    # Callback to make "url" a valid URI, as long as it appears to be valid.
    #
    # e.g., "abc.x/345" is not a valid URI because there is no domain of "x"
    def add_scheme_to_url
      self.url = ModuleUrlUtil.url_prepended_with_scheme(self.url)
    end

    # Callback to adjust "url", trimming an unnecessary prefix slash(es), truncating multiple slashes at the tail
    #
    def adjust_url_minimum
      self.url = self.class.minimum_adjusted_url(self.url)
    end

    # Callback to set url_normalized
    #
    # Prefix "https" is allowed, but removed on save.
    # Port number is allowed, but removed on save.
    # A trailing forward slash is allowed, but removed on save.
    #
    # The callback {add_scheme_to_url} is assumed to be called before this.
    def normalize_url
      self.url_normalized = Addressable::URI.unencode(self.class.normalized_url(url))  # URI.decode_www_form_component would fail in Domain with non-ASCII
    end

    # Callback to modify url_langcode
    #
    def normalize_url_langcode
      self.url_langcode = url_langcode.strip.downcase if url_langcode
    end

    # Should have a valid host with/without a scheme
    def url_validity
      if !ModuleUrlUtil.valid_url_like?(url)
        errors.add(:url, " url does not appear to be a valid URL")
      end
    end

end


class << Url
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  #
  # "url" is mandatory
  def create_basic!(*args, domain: nil, domain_id: nil, **kwds, &blok)
    opts = _get_options_for_create_basic(domain, domain_id, kwds)
    create_basic_bwt!(*args, **opts, &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  def initialize_basic(*args, domain: nil, domain_id: nil, **kwds, &blok)
    opts = _get_options_for_create_basic(domain, domain_id, kwds)
    initialize_basic_bwt(*args, **opts, &blok)
  end

    def _get_options_for_create_basic(domain, domain_id, kwds)
      opts = {}.merge(kwds).with_indifferent_access
      if !opts.has_key?(:title) || opts[:title].blank?
        opts[:title] = "create-basic-"+(opts[:url] || "blank-domain-#{rand.to_s}")
      end
      if !opts.has_key?(:langcode) || opts[:langcode].blank?
        opts[:langcode] = "ja"
      end
      domain_id ||= (domain ? domain.id : (Domain.unknown || Domain.create_basic!(*args)).id)
      opts[:domain_id] = domain_id
      opts
    end
    private :_get_options_for_create_basic
end

