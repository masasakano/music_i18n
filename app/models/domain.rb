# == Schema Information
#
# Table name: domains
#
#  id                                                   :bigint           not null, primary key
#  domain(Domain or any subdomain such as abc.def.com)  :string
#  note                                                 :text
#  weight(weight to sort this model within DomainTitle) :float
#  created_at                                           :datetime         not null
#  updated_at                                           :datetime         not null
#  domain_title_id                                      :bigint           not null
#
# Indexes
#
#  index_domains_on_domain           (domain) UNIQUE
#  index_domains_on_domain_title_id  (domain_title_id)
#
# Foreign Keys
#
#  fk_rails_...  (domain_title_id => domain_titles.id) ON DELETE => cascade
#
class Domain < ApplicationRecord
  include ModuleWeight  # adds a validation

  belongs_to :domain_title

  has_many :urls,    dependent: :restrict_with_exception  # Exception in DB, too.
  has_one :site_category, through: :domain_title

  attr_accessor :notice_messages

  # NOTE: UNKNOWN_TITLES used in ModuleUnknown (this model does not include it, but this uses the same-name one anyway).
  UNKNOWN_TITLES = {
    "ja" => ['www.example.com', nil],
    "en" => ['www.example.com', nil],
    "fr" => ['www.example.com', nil],
  }.with_indifferent_access

  # Specific to this model
  UNKNOWN_TITLE = UNKNOWN_TITLES[:en].first

  # String expression of the core part of Regular expression of a Domain
  # c.f., https://stackoverflow.com/questions/1128168/validation-for-url-domain-using-regex-rails/16931672
  REGEXP_DOMAIN_CORE_STR = "(?-mix:[a-z0-9]+([\\-\\.]{1}[a-z0-9]+)*\\.[a-z]{2,63})"

  # Regular expression of a Domain to be saved in DB
  REGEXP_DOMAIN = /\A#{REGEXP_DOMAIN_CORE_STR}\z/

  # Callback
  before_validation :normalize_domain

  validates :domain, presence: true
  validates_uniqueness_of :domain
  validates_format_of :domain, with: REGEXP_DOMAIN

  # @param reload [void] Always ignored. Just for conistency with ModuleUnknown
  def self.unknown(reload: nil)
    find_by(domain: UNKNOWN_TITLE) 
  end

  def unknown?
    self == self.class.unknown
  end

  # @param url [String, Url]
  # @return [SiteCategory] gussed based on the given url
  def self.guess_site_category(url)
    uri = URI.parse( ModuleUrlUtil.url_prepended_with_scheme(url) )
    return SiteCategory.unknown if uri.host.blank?

    /([^.]+\.[^.]+)$/ =~ uri.host
    top_domain = $1

    cand = Domain.where(domain: top_domain).or(Domain.where("domain LIKE ?", "%"+top_domain)).order(:created_at).first
    cand ? cand.site_category : SiteCategory.unknown
  end

  # Finds Domain with the exact Domain from the given URL String
  #
  # @param url_str [String]
  # @return [Domain, NilClass]
  def self.find_by_urlstr(url_str)
    where(domain: extracted_normalized_domain(url_str.strip)).first
  end

  # Finds Domain with Domain of with or without "www."
  #
  # @param url_str [String, URI]
  # @param except: [Integer, String, ActiveRecord, NilClass] for the purpose of specifying self when called from an instance method.
  # @return [Domain, NilClass]
  def self.find_by_both_urls(url_str, except: nil) #, is_normalized_no_www: false)  # 
    domain_norm_no_www = extracted_normalized_domain(url_str.to_s.strip).sub(/\Awww\./, "")
    except_id = (except.respond_to?(:id) ? except.id : except)
    # domain_norm_no_www = (is_normalized_no_www ? url_str : extracted_normalized_domain(url_str.strip).sub(/\Awww\./, ""))  ## NOTE: Sometimes, the caller actually preprocesses the String. Then, to process it here again would be an overlap, so I once included the argument to indicate it. However, I have encountered a case, where the caller wrongly passed the unprocessed argument, yet tagging it processed. It took half an hour to pin down where.  So, it is much safer (and far more productive for developers) to process it here whatever even though it could be in some cases a bit redundant.
    where(domain: [domain_norm_no_www, "www."+domain_norm_no_www]).where.not(id: except_id).first
  end

  # Finds all Domains from URL (String)
  #
  # @return [Domain::ActiveRecord_Relation] maybe empty.
  def self.find_all_siblings_by_urlstr(url_str, except: nil)
    dt = DomainTitle.find_by_urlstr(url_str)

    return self.none if !dt
    return dt.domains if !except
           dt.domains.where.not(id: except.id)
  end

  # Find {Domain} or create one, maybe along with DomainTitle
  #
  # Returned Domain may have {Domain#notice_messages} (Array<String>)
  # for flash (notice) messages.
  #
  # @param url_str [String] With or without "www."; the difference is significant in creating a new Domain
  # @param site_category_id: [NilClass, String, Integer] Used only in create. ignored if nil. auto-guessed if "". See {Domain.find_or_initialize_domain_title_to_assign} and {Domain.guess_site_category}
  # @return [Domain, NilClass]
  def self.find_or_create_domain_by_url!(url_str, site_category_id: nil)
    domain_norm = extracted_normalized_domain(url_str.strip)
    record = find_by_urlstr(domain_norm)

    if record
      record.notice_messages ||= []
      record.notice_messages.push "Domain identified: #{record.domain}"
      update_site_category_parent!(record, site_category_id: site_category_id) if site_category_id  # true if empty (="")
      return record
    end

    record = Domain.new(domain: domain_norm)

    record.notice_messages ||= []
    dt = record.find_or_initialize_domain_title_to_assign(site_category_id: site_category_id)  # This would never be an Integer b/c record is a new_record?
    if !dt  # This happens only if record.domain.blank? for an "existing" Domain - should never happen!
      record.save!  # should fail.
      return record
    end

    msgs = []
    ActiveRecord::Base.transaction(requires_new: true) do
      if dt.new_record?
        dt.save! 
        msgs.push "DomainTitle created: "+dt.reload.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "")
      end
      record.domain_title_id = dt.id
      record.save!
      msgs.push "Domain created: "+record.domain.to_s
    end
    record.notice_messages.concat msgs

    record
  end

  # Updates associated {DomainTitle#site_category} if specified so.
  #
  # The caller put the call inside a DB transaction.
  #
  # @param domain [Domain]
  # @param site_category_id: [NilClass, String, Integer] Used only in create. ignored if nil. auto-guessed if "". See {Domain.find_or_initialize_domain_title_to_assign} and {Domain.guess_site_category}
  # @return [Domain]
  def self.update_site_category_parent!(domain, site_category_id: nil)
    return domain if site_category_id.nil?
    if "" == site_category_id
      site_category_id = guess_site_category(domain.domain).id
    end
    return if domain.site_category.id.to_s == site_category_id.to_s

    ## DomainTitle updates (bang)
    domain.domain_title.update!(site_category_id: site_category_id)

    domain.notice_messages ||= []
    domain.notice_messages.push "DomainTitle's SiteCategory updated to #{domain.site_category.title_or_alt(prefer_shorter: false, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "(NO TITLE)", article_to_head: true)}"
    domain
  end

  # Find DomainTitle, especially when domain_title_id is nil (reset in WWW form?)
  #
  # @param site_category_id: [NilClass, String, Integer] Used only in create. ignored if nil. auto-guessed if ""
  # @return [Integer, DomainTitle, NilClass] {#domain_title_id} or new (unsaved) {DomainTitle}.
  def find_or_initialize_domain_title_to_assign(site_category_id: nil)
    return domain_title_id.to_i if domain_title_id.present?  # Integer (should be a valid pID of DomainTitle, but unchecked.
    return if domain.blank?  # self is not valid?

    domain_norm_no_www = self.class.extracted_normalized_domain(domain.strip).sub(/\Awww\./, "")
    if (record = self.class.find_by_both_urls(domain_norm_no_www))
      ret = record.domain_title  ## DomainTitle identified and assigned
      return ret  # DomainTitle
    end

    opts = {}
    if "" == site_category_id
      site_category_id = self.class.guess_site_category(domain).id
    end
    opts[:site_category_id] = site_category_id if site_category_id

    DomainTitle.new_from_url(domain_norm_no_www, **opts)  # new DomainTitle
  end
  
  # Wrapper of ModuleUrlUtil.normalized_url with a specific combination of options
  #
  # This extracts a domain part from a given URI, excluding the scheme, preserving "www.",
  # with no trailing forward slash (at the end of the domain), path, or queries/fragments
  # This may be used by a Controller?
  #
  # @note
  #   port is ignored.  Ideally, port number should be held as a different attribute/column. TODO?
  #
  # @param url_in [String]
  # @param with_www: [Boolean] If true (Def), the "www." part in the path is, if present, not trimmed.  If the input does not have it, the return does not have it, either.
  # @return [String]
  def self.extracted_normalized_domain(url_in, with_www: true)
    ModuleUrlUtil.normalized_url(url_in, with_scheme: false, with_www: with_www, with_port: false, with_path: false, with_extra_trailing_slash: true, with_query: false, with_fragment: false, delegate_special: false)
  end

  # Reassesses and maybe resets the associated {SiteCategory} with the parent DomainTitle
  #
  # This modifies DB. So, the caller should put this inside a DB transaction.
  #
  # @string url_str [String, NilClass] if nil, self.domain is used.
  # @return [SiteCategory, NilClass] if {DomainTitle.site_category_id} is reset, returns the update-associated SiteCategory.
  def reset_site_category!(url_str=nil)
    url_str = domain if url_str.blank?
    scat = self.class.guess_site_category(url_str)
    return if scat == site_category

    domain_title.update!(site_category: scat)
    scat
  end

  # At the association level (NOT the user-permission level)
  def destroyable?
    !urls.exists?
  end


  # Not inherited.
  def self.create_basic!(*args, domain:, domain_title: nil, domain_title_id: nil, site_category: nil, site_category_id: nil, **kwds, &blok)

    ret = Domain.new(*args, domain: domain, **kwds, &blok)
    site_category_id = _get_site_category_id_arg(domain, site_category, site_category_id)  # maybe nil but never "" unless domain is blank?
    dt = ret.find_or_initialize_domain_title_to_assign(site_category_id: site_category_id)
    dt.save!
    ret.domain_title = dt
    ret.save!
    ret
  end

  # Not inherited.
  # Unlike {#create_basic!}, site_category is ignored.
  def self.initialize_basic(*args, site_category: nil, site_category_id: nil, **kwds, &blok)
    Domain.new(*args, domain_title_id: DomainTitle.first, **kwds, &blok)
  end

    ## utility method
    #
    # @param domain [String]
    def self._get_site_category_id_arg(domain, site_category, site_category_id)
      if site_category
        site_category.id
      elsif "" == site_category_id
        Domain.guess_site_category(domain).id
      else
        site_category_id
      end
    end
    private_class_method :_get_site_category_id_arg

  private

    # Callback
    #
    # Prefix "https" is allowed, but removed on save.
    # Port number is allowed, but removed on save.
    # A trailing forward slash is allowed, but removed on save.
    def normalize_domain
      ### This class method modifies the input too aggressively; it removes the path part.
      ### For a Model it is too aggressive.  If a path part is included, it should fail a vlidation.
      # self.domain = self.class.extracted_normalized_domain(domain)

      if /\A\s*(?:(?:https?|file):\/\/)?(#{REGEXP_DOMAIN_CORE_STR})(?::[0-9]{1,5})?(?:\/)?\s*\z/ix =~ domain
        # Assuming a path part is NOT included.
        self.domain = $1.downcase  # excluding a scheme and a port if any
      end

    end
end

