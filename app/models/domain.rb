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

  # Finds Domain with Domain of with or without "www."
  #
  # @param url_str [String]
  # @param except: [Integer, String, ActiveRecord, NilClass] basically, excluding self (if called from an instance method).
  # @return [Domain, NilClass]
  def self.find_domain_by_both_urls(url_str, except: nil) #, is_normalized_no_www: false)  # 
    domain_norm_no_www = extracted_normalized_domain(url_str.strip).sub(/\Awww\./, "")
    except_id = (except.respond_to?(:id) ? except.id : except)
    # domain_norm_no_www = (is_normalized_no_www ? url_str : extracted_normalized_domain(url_str.strip).sub(/\Awww\./, ""))  ## NOTE: Sometimes, the caller actually preprocesses the String. Then, to process it here again would be an overlap, so I once included the argument to indicate it. However, I have encountered a case, where the caller wrongly passed the unprocessed argument, yet tagging it processed. It took half an hour to pin down where.  So, it is much safer (and far more productive for developers) to process it here whatever even though it could be in some cases a bit redundant.
    where(domain: [domain_norm_no_www, "www."+domain_norm_no_www]).where.not(id: except_id).first
  end

  # Finds Domain with the exact Domain from the given URL String
  #
  # @param url_str [String]
  # @return [Domain, NilClass]
  def self.find_domain_by_url(url_str)
    where(domain: extracted_normalized_domain(url_str.strip)).first
  end

  # Find {Domain} or create one, maybe along with DomainTitle
  #
  # Returned Domain may have {Domain#notice_messages} (Array<String>)
  # for flash (notice) messages.
  #
  # @param url_str [String] With or without "www."; the difference is significant in creating a new Domain
  # @return [Domain, NilClass]
  def self.find_or_create_domain_by_url!(url_str)
    domain_norm = extracted_normalized_domain(url_str.strip)
    record = find_domain_by_url(domain_norm)

    if record
      record.notice_messages ||= []
      record.notice_messages.push "Domain identified: #{record.domain}"
      return record
    end

    record = Domain.new(domain: domain_norm)

    record.notice_messages ||= []
    dt = record.find_or_initialize_domain_title_to_assign  # This would never be an Integer b/c record is a new_record?
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

  # Find DomainTitle, especially when domain_title_id is nil (reset in WWW form?)
  #
  # @return [Integer, DomainTitle, NilClass] {#domain_title_id} or new (unsaved) {DomainTitle}.
  def find_or_initialize_domain_title_to_assign
    return domain_title_id.to_i if domain_title_id.present?  # Integer (should be a valid pID of DomainTitle, but unchecked.
    return if domain.blank?  # self is not valid?

    domain_norm_no_www = self.class.extracted_normalized_domain(domain.strip).sub(/\Awww\./, "")
    if (record = self.class.find_domain_by_both_urls(domain_norm_no_www))
      ret = record.domain_title  ## DomainTitle identified and assigned
      return ret  # DomainTitle
    end

    DomainTitle.new_from_url(domain_norm_no_www)  # new DomainTitle
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

  # At the association level (NOT the user-permission level)
  def destroyable?
    !urls.exists?
  end

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
