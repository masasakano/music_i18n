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

  include ModuleWasFound # defines attr_writers @was_found, @was_created and their questioned-readers. (8 methods)
  define_was_found_for("domain")       # defined in ModuleWasFound; defines domain_found? etc. (8 methods)
  define_was_found_for("domain_title") # defined in ModuleWasFound; defines domain_title_found? etc. (8 methods)

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Basically, Translation never violates uniquness because URL aliases are possible!  (We don't prohibit URL aliases.)
  # If URL aliases are considered in the future, the uniquness can be able to be assessed if
  #   Url#domain, Url#url_langcode
  #   Translation#title-ISH, Translation#langcode
  #   Not-Alias
  # are all identical, perhaps.
  TRANSLATION_UNIQUE_SCOPES = :disable  # changed from :default

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
  def anchorables
    anchorings.map(&:anchorable)
  end
  def sorted_anchorables
    anchorables.sort_by{|a| [a.class.name,
                             a.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "\uFFFD", article_to_head: false),
                             a.id] }
  end

  validates :url, presence: true
  validates :url,            uniqueness: {case_sensitive: false, scope: :url_langcode}
  validates :url_normalized, uniqueness: {case_sensitive: false}  # scheme, port, "www." do not matter. case-insensitive INCLUDING the path/query/fragment part. Empty query/fragment ignored.
  validate  :url_validity   # Should have a valid host with/without a scheme.
  validates :url_langcode, length: {is: 2}, format: {with: /\A[a-z]{2}\z/i}, allow_nil: true, allow_blank: true  # so far, "-" etc are not allowed.
  validates :last_confirmed_date, comparison: { greater_than_or_equal_to: :published_date }, allow_nil: true

  attr_accessor :original_path  # Input path (String) used in some methods. Not used in forms.

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
  # {Url#original_path} is set.
  #
  # @note
  #   Url is unique by {#url_normalized}
  #
  # @param urlstr [String] mandatory.
  # @return [Url, NilClass]
  def self.find_url_from_str(urlstr)
    (ret = find_by(url_normalized: normalized_url(urlstr))) || return
    ret.original_path = urlstr
    ret.was_found = true
    ret.domain_found = true if ret.domain
    ret
  end

  # Alternative constructor from String URL
  #
  # {Url#url} is as the user (editor) specifies — no change or normalization, including case-sensitivity,
  # except that a null query or fragment is removed and multiple trailing slashes are
  # truncated to one as in before_validation.  And a scheme ("https://") is added if not present.
  #
  # {#was_created?}, {#domain_found?} (or not), {#original_path} are set.
  #
  # @param urlstr [String] mandatory
  # @param encode: [NilClass, Boolean] If true (Def: false), encode urlstr
  # @param site_category_id: [NilClass, String, Integer] Used only in creating DomainTitle. ignored if nil. auto-guessed if "".  See {Domain.find_or_initialize_domain_title_to_assign} and {Domain.guess_site_category}
  # @param **kwds [Hash] You can initialize any of the standard attributes of Url, plus its Translation. All are optional, and can be automatically set.
  # @return [Url] In failing, +errors+ may be set or +id+ may be nil. +domain+ may be set and +domain.notice_messages+ may be significant (to show as flash messages).
  def self.create_url_from_str(urlstr, encode: false, site_category_id: nil, url_langcode: nil, domain: nil, domain_id: nil, weight: nil, published_date: nil, last_confirmed_date: nil, note: nil, memo_editor: nil, title: nil, langcode: nil, is_orig: nil, alt_title: nil, fetch_h1: false)  # fetch_h1 is totally ignored for now!
    raise ArgumentError, 'positive fetch_h1 unsupported so far' if fetch_h1
    newurl = self.new(url: (encode ? ModuleUrlUtil::encoded_urlstr_if_decoded(urlstr) : urlstr),
                     url_langcode: url_langcode,
                     weight: weight,
                     published_date: published_date,
                     last_confirmed_date: last_confirmed_date,
                     note: note,
                     memo_editor: memo_editor)
    newurl.domain    = domain    if domain
    newurl.domain_id = domain_id if domain_id
    newurl.was_created = true  # domain_found will be set in find_or_create_and_reset_domain_id
    newurl.original_path = urlstr  # as given (without encode/unencode processing here)

    newurl.unsaved_translations << def_translation_from_url(newurl, title: title, langcode: langcode, is_orig: is_orig, alt_title: alt_title)

    ret = newurl.find_or_create_and_reset_domain_id(site_category_id: site_category_id)
    return newurl if !ret  # "newurl.errors" should have been set.  "newurl.id" is nil.

    newurl.save
    newurl  # In failing, "newurl.errors" should be set.  If successful, a Translation should have been also created.
  end

  # @param urlstr [String, NilClass] this may be just a partial String like "HARAMIchan" (at the time of writing).
  # @param assess_host_part: [Boolean] if true (Def: false) and if +urlstr+ contradicts a Wikipedia Domain, returns nil. Else, no Domain check is performed.
  # @return [Url, NilClass] {#was_found} is set.
  def self.find_url_from_wikipedia_str(urlstr, url_langcode: nil, assess_host_part: false)
    find_url_from_str( _construct_valid_url_from_wikipedia_str(urlstr, url_langcode: url_langcode, assess_host_part: assess_host_part) )
  end

  # Wrapper of create_url_from_str
  #
  # @param assess_host_part: [Boolean] if true (Def: false) and if +urlstr+ contradicts a Wikipedia Domain, returns nil. Else, no Domain check is performed.
  # @param urlstr [String, NilClass] this may be just a partial String like "HARAMIchan" (at the time of writing).
  # @return [Url, NilClass]
  def self.find_or_create_url_from_wikipedia_str(urlstr_in, url_langcode: nil, domain_id: nil, anchorable: nil, assess_host_part: false, **opts)
    urlstr = _construct_valid_url_from_wikipedia_str(urlstr_in, url_langcode: url_langcode, assess_host_part: assess_host_part) || return
    url = find_url_from_wikipedia_str(urlstr, url_langcode: url_langcode, assess_host_part: assess_host_part)
    return url if url  # {#was_found} is set.

    hsopts = params_for_wiki(urlstr)
    hsopts ||= {
      url_langcode: url_langcode,
      domain_id: (domain_id || Domain.find_by(domain: "w.wiki")&.id),  # Integer or potentially nil.
    }
    if hsopts[:title].blank? && anchorable.respond_to?(:title)
      hsopts[:title] = anchorable.title+" (Wikipedia)"  # This happens only for "w.wiki" Domain.  So, exceptionally, a postfix is appended (because we don't know exactly what the Wikipedia title would be, which can be essential in using the Wikipedia API)
    end

    opts2pass = opts.merge(indifferent_access_to_sym_keys(hsopts))
    create_url_from_str(urlstr, **opts2pass)  # was_created? and domain_found? are set.
  end

  # Returns a valid Url String for a proper Wikipedia Url (with a scheme) or nil
  #
  # This method was developed to deal with the legacy wiki_ja/en attributes of Artist,
  # which may not contain a scheme part or even domain part.  For this reason,
  # the default of +assess_host_part+ is false, which means if the given argument is
  # "http://example.com", the returned String will be "http://example.com" despite
  # it is nothing like Wikipedia Url.
  #
  # @param urlstr [String, NilClass] this may be just a partial String like "HARAMIchan" (at the time of writing).
  # @param url_langcode: [String, NilClass] locale
  # @param assess_host_part: [Boolean] if true (Def: false) and if +urlstr+ contradicts a Wikipedia Domain, returns nil. Else, no Domain check is performed.
  # @return [String, NilClass] valid URL-string with a scheme or nil if blank or invalid.
  def self._construct_valid_url_from_wikipedia_str(urlstr, url_langcode: nil, assess_host_part: false)
    return if urlstr.blank?
    urlstr = urlstr.strip
    url_w_scheme = ModuleUrlUtil.url_prepended_with_scheme(urlstr, invalid: nil)  # return may be nil.
    if url_w_scheme
      uri = ModuleUrlUtil.get_uri(url_w_scheme)
      return nil if assess_host_part && !in_wikipedia?(url_w_scheme)
      # (/^([a-z]{2})\./ =~ uri.host) && url_langcode ||= $1
    elsif !url_langcode.present?
      raise "Not like Wikipedia URL (or you should specify url_langcode)."
    else
      urltmp = 
        if /^#{url_langcode}\./ =~ urlstr  # if no scheme
          "https://"+urlstr
        else                         # if only path part
          "https://#{url_langcode}.wikipedia.org/wiki/"+urlstr
        end
      uri = ModuleUrlUtil.get_uri(urltmp)
      return if !uri
    end
    urlstr = uri.to_s
  end
  private_class_method :_construct_valid_url_from_wikipedia_str

  # @param uri [URI, Url, Domain, String]
  # @return [Boolean] true if the given +uri+ looks like Wikipedia's one
  def self.in_wikipedia?(uri)
    return ("wikipedia" == uri.site_category.mname) if uri.respond_to?(:site_category)

    # Now, either URI (Addressable::URI) or String
    domain_str = (uri.respond_to?(:host) ? uri : (ModuleUrlUtil.get_uri_from_any(uri.to_s, invalid: nil) || (return false))).host
    raise ArgumentError, "No proper domain-like URI (or String) is specified." if domain_str.blank?
    return true if SiteCategory.find_by(mname: "wikipedia").domains.find_by(domain: domain_str)
    !!(%r@^[a-z]{2}\.wikipedia\.org$@i =~ domain_str)
  end

  def in_wikipedia?
    self.class.send(__method__, self)
  end

  # Returns an Array of old Child Anchoring records
  #
  # @return [Array<ActiveRecords>]
  def anchoring_parents
    anchorings.map(&:anchorable)
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
    set_domain_found_true if domain.present?
    return self if !domain_id.blank? && !force

    begin
      self.domain = Domain.find_or_create_domain_by_url!(url, site_category_id: site_category_id)
    rescue HaramiMusicI18n::Domains::CascadeSaveError => err
      errors.add :domain_id, compile_captured_err_msg(err)  # defined in ModuleCommon (to clarify for editors what error is raised)
      return  # an error happens.
    # rescue HaramiMusicI18n::InconsistentDataIntegrityError
      ## This happens when SiteCategory.default is undefined (which should never happen in normal operations).
    end

    set_domain_found_if_true( self.domain.was_found? ) if domain.present?  # defined in ModuleWasFound
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
    self.domain_found = true if self.domain  # should be always true.
    return self.domain if !force && !url_changed? && (site_category_id.nil? || site_category_id.to_s.strip == domain_title.site_category_id.to_s)
    domain_title_bkup = self.domain_title
    domain_bkup       = self.domain

    find_or_create_and_reset_domain_id(force: force, site_category_id: site_category_id)  # maybe a created one.
    set_domain_found_if_true( self.domain.was_found? )  # defined in ModuleWasFound

    self.domain != domain_bkup || self.domain_title != domain_title_bkup
  end

  # called from Anchoring Controller
  #
  # @param title_str [String]
  # @return [Boolean, String, NilClass] nil if update failed, in which case {#errors} is set
  def update_best_translation(title_str)
    translations.reset
    tra = 
      if (cnt=translations.count) > 1
        errors.add(:title, "Url has multiple translaitons, so a simple update is rejected. Update it with the dedicated UI.")
        return
      elsif cnt == 1
        translations.first
      else
        Translation.new(translatable_type: self.class.name, translatable_id: self.id)
      end

    tra.title = title_str
    guessed_lcode = guess_lang_code(title_str)
    if guessed_lcode == "ja"  # to avoid potential violation.
      msg = sprintf("Locale of Translation changed from %s to %s.", tra.langcode.inspect, '"ja"') if tra.langcode != "ja"
      tra.langcode = "ja"
    end

    status = tra.save
    return (msg || status) if status
    #  add_flash_message(:notice, msg) if msg

    tra.errors.each do |err|
      errors.add(:title, "Failed to #{method} Translation#title (#{title_str.inspect}) failed.")
    end
    nil
  end

  # Find Urls for anchorable#note, creating ones that are not present, optionally removing the URL-Stgings in the note
  #
  # If the same-ISH URL-Strings appear in the note, only the last one is (optionally) removed.
  # Accordingly, the order of the returned Array of Urls is *reversed* from the URL-like Strings
  # in the note.
  #
  # @example
  #    Url.find_or_create_multi_from_note(Place.last){|valid_path, orig_path| true }
  #      # => e.g., [u=Url.unknown, Url("https://www.some.org/ab?q=3#x"), ...]
  #      #    # u.original_path == "www.example.com" (for example!)
  #
  # @param anchorable [ActiveRecord, String] anchorable one, or its anchorable_type (namely its class name)
  # @param id_anchorable [Integer, String, NilClass] pID of anchorable. mandatory when anchorable is anchorable_type.
  # @param fetch_h1: [Boolean] If true, fetches the title from the remote URL on create.
  # @return [Array<Url>]
  def self.find_or_create_multi_from_note(anchorable, id_anchorable=nil, fetch_h1: false, &bl)
    # Array of either Url or Array[ValidPathString, OrigString]
    url_or_strarys = find_multi_from_note(anchorable, id_anchorable, &bl)

    # Processing in the reverse order because the URLs embedded at the tail of Note should be removed first.
    artmp = []
    arret = url_or_strarys.reverse.uniq.map{ |url_or_strary|
      next nil if artmp.include? url_or_strary  # duplication to be truncated
      artmp << url_or_strary  # to check duplication in the later processes in this iterator.  The last element may be overwritten a few lines below.
      next url_or_strary if !url_or_strary.respond_to?(:flatten)

      path_valid, path_orig = url_or_strary
      hsopts = _prepare_create_opts_from_ary(path_valid, path_orig, fetch_h1, &bl)

      artmp[-1] = create_url_from_str(path_orig, encode: true, **hsopts)&.tap(&:set_was_created_true)  # Url#original_path will be set
    }.compact

    arret  # of Url-s. They may have errors.
  end

  # @return [Hash] with Symbol keys
  def self._prepare_create_opts_from_ary(path_valid, path_orig, fetch_h1)
    hsopts = ((block_given? ? yield(path_valid, path_orig) : _params_for_website(path_valid)) || {})
    return indifferent_access_to_sym_keys(hsopts) if !fetch_h1  # defined in module_common.rb

    h1 = fetch_url_h1(path_valid)  # defined in module_common.rb; return is guaranteed to be a String already stripped.
    if h1.blank?  # singleton method {#message}
      ## Warning for console
      warn h1.message 
    else
      hsopts[:title] = h1
    end
    indifferent_access_to_sym_keys(hsopts)  # defined in module_common.rb
  end
  private_class_method :_prepare_create_opts_from_ary
  
  # Removed {#original_path} string from anchorable#note, saving anchorable.
  #
  # Assuming {#original_path} is defined; any Url processed here should have it defined.
  # The caller should check with the anchorable for errors.any?
  #
  # @param anchorable [ActiveRecord] its note is now modified.
  # @return [Boolean, NilClass] true if saving succeeds, false if fails. nil if the proposition is weirdly not satisfied
  def remove_str_from_note(anchorable)
    if original_path.blank?
      Rails.logger.error "ERROR(#{__method__}): Url#original_path is blank, which should never happen: "+inspect
      return
    elsif !anchorable.note
      Rails.logger.error "ERROR(#{__method__}): #{anchorable.class.name}#note for pID=(#{anchorable.id}) is nil, which should never happen: Url="+inspect
      return
    end
     
    last_match_info = nil
    anchorable.note.scan(/(\s*<?#{Regexp.quote(original_path)}>?\s*)/){ last_match_info = [Regexp.last_match.begin(0), $1.size] }
    anchorable.note[last_match_info[0], last_match_info[1]] = " "  # Enclosing spaces are truncated to one space (NOT zero)
    anchorable.save   # WARNING: may set anchorable.errors
  end

  # Find existing Urls from anchorable#note String
  #
  # Returning an Array of (possibly) mixtures of {Url}-s and an Arrays of
  # pairs of a Url-valid String and its original extracted String,
  # based on the output of {ModuleUrlUtil#extract_url_like_string_and_raws}, preserving
  # its order. Chances are multiple Url instances
  # pointing to a common DB Url record may be contained in the Array.
  #
  # Some of the elements are filtered out in return.
  # The caller may pass a block for the filtering purpose to return true for selecting or false to filter out,
  # based on the same 2 arguments (valid path and original String).
  # If no block is given, the default filtering method is applied.
  #
  # For each Url returned, {Url#original_path{ is set.
  #
  # @example
  #    Url.find_multi_from_note(Place.last){|valid_path, orig_path| true }
  #      # => e.g., [u=Url.unknown, ["https://www.some.org/ab?q=3#x", "www.some.org/ab?q=3#x"], Url.second]
  #      #    # u.original_path == "www.example.com" (for example!)
  #
  # @param anchorable [ActiveRecord, String] anchorable one, or its anchorable_type (namely its class name)
  # @param id_anchorable [Integer, String, NilClass] pID of anchorable. mandatory when anchorable is anchorable_type.
  # @return [Array<Url, Array<String, String>>]
  def self.find_multi_from_note(anchorable, id_anchorable=nil)
    anchorable = _get_anchorable_from_arg(anchorable, id_anchorable)
    ModuleUrlUtil.extract_url_like_string_and_raws(anchorable.note).map{ |valid_path_str, orig_str| # [%w(https://youtu.be/XXX youtu.be/XXX), ...]
      if (block_given? ? yield(valid_path_str, orig_str) : valid_url_str_to_transfer_from_note?(valid_path_str))
        find_url_from_str(orig_str) || [valid_path_str, orig_str]  # the former sets {#original_path} and {#was_found?}==true
      else
        nil
      end
    }.compact
  end

  # @return [Boolean] true if the path can be transferred from anchorable#note to Url.
  def self.valid_url_str_to_transfer_from_note?(valid_path, _=nil)
    return true if params_for_wiki(valid_path)
    return true if params_for_harami_chronicle(valid_path)
    return true if Rails.env.test? && (u=find_url_from_str(valid_path)) && u.domain.unknown?  # In test environment, there is quite a overload...
    false
  end

  # @return [Hash, nil] nil if not in one of the candidate websites examined in this method
  def self._params_for_website(valid_path, _=nil)
    params_for_wiki(valid_path) ||
      params_for_harami_chronicle(valid_path)
  end
  private_class_method :_params_for_website

  # Transfer Harmai-Chronicle-URL from anchorable#note
  #
  # @param anchorable [ActiveRecord, String] anchorable one, or its anchorable_type (namely its class name)
  # @param id_anchorable [Integer, String, NilClass] pID of anchorable. mandatory when anchorable is anchorable_type.
  # @return [ActiveRecord] anchorable one
  def self._get_anchorable_from_arg(anchorable, id_anchorable)
    return anchorable if anchorable.respond_to?(:anchorings)
    raise HaramiMusicI18n::Urls::NotAnchorableError, "Argument is neither anchorable ActiveRecord nor its class name" if !anchorable.respond_to?(:constantize)

    begin
      ret = anchorable.constantize.find(id_anchorable)
    rescue NoMethodError, NameError  # former for nil etc, latter for "lower_case_string" etc.
      raise ArgumentError, "Url.#{__method__}: Argument (#{anchorable.inspect}) is neither anchorable ActiveRecord nor its class name"
    end

    raise HaramiMusicI18n::Urls::NotAnchorableError, "Argument is not anchorable ActiveRecord" if !ret.respond_to?(:anchorings)
    ret
  end
  private_class_method :_get_anchorable_from_arg

  # Returns a params Hash if the given String is from Wikipedia
  #
  # @todo caching mechanism as this is called twice from Url
  #
  # @param urin [String] any String, maybe looking like URL, e.g., http://example.com, www.example.com/abc
  # @return [Hash, NilClass] if the given String is like URL and that of Wikipedia, returns params-like Hash (with_indifferent_access) to update, else nil.
  def self.params_for_wiki(urlstr)
    urin = ModuleUrlUtil.get_uri(urlstr)
    return if urin.blank? || urin.host.blank? || /^([a-z]{2})\.wikipedia\.org$/ !~ (dom=urin.host.downcase)  # Not Wikipedia

    reths = {}.with_indifferent_access
    reths["url_langcode"] = $1
    reths["domain_id"]    = Domain.find_by(domain: dom)&.id  # Integer or potentially nil.

    reths["title"] = Addressable::URI.unencode(urin.path.sub(%r@^/?wiki/@, "")).gsub(/_/, " ")  # n.b., the main path part for Wikipedia title may include forward slashes "/"; e.g., https://ja.wikipedia.org/wiki/%E6%AE%8B%E9%9F%BF%E6%95%A3%E6%AD%8C/%E6%9C%9D%E3%81%8C%E6%9D%A5%E3%82%8B
    reths["langcode"] = reths["url_langcode"]
    reths["is_orig"] = true
    reths
  end

  # Returns a params Hash if the given String is from Harami-Chronicle
  #
  # @todo caching mechanism as this is called twice from Url
  #
  # @param urin [String] any String, maybe looking like URL, e.g., http://example.com, www.example.com/abc
  # @return [Hash, NilClass] if the given String is like URL and that of Harami-Chronicle, returns params-like Hash (with_indifferent_access) to update, else nil.
  def self.params_for_harami_chronicle(urlstr)
    dt = DomainTitle.find_by_urlstr(urlstr)
    return if !dt
    sc = dt.site_category
    return if !sc || "chronicle" != sc.mname
    return if dt != sc.domain_titles.order(:created_at).first  # Chronicle but not the default (=first seeded) one.

    reths = {}.with_indifferent_access
    urin = ModuleUrlUtil.get_uri(urlstr)
    dt.domains.each do |domain|
      if domain.domain == urin.host
        reths["domain_id"] = domain.id if reths["domain_id"].blank?
        break
      end
    end
    reths["url_langcode"] = "ja"
    reths
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

