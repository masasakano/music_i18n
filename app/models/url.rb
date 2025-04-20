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
  before_validation :normalize_url
  before_validation :normalize_url_langcode

  belongs_to :domain

  has_one :domain_title, through: :domain
  has_one :site_category, through: :domain_title

  validates :url, presence: true
  validates :url, uniqueness: {scope: :url_langcode, case_sensitive: false}
  validate  :url_validity  # Should have a valid host with/without a scheme.
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
    ModuleUrlUtil.normalized_url(url_in, with_scheme: false, with_www: false, with_port: false, with_extra_trailing_slash: false, with_path: true, with_query: true, with_fragment: true)
  end

  private

    # Callback to make "url" a valid URI, as long as it appears to be valid.
    #
    # e.g., "abc.x/345" is not a valid URI because there is no domain of "x"
    def add_scheme_to_url
      self.url = ModuleUrlUtil.scheme_and_uri_string(self.url).join if !self.url
    end

    # Callback to set url_normalized
    #
    # Prefix "https" is allowed, but removed on save.
    # Port number is allowed, but removed on save.
    # A trailing forward slash is allowed, but removed on save.
    #
    # The callback {add_scheme_to_url} is assumed to be called before this.
    def normalize_url
      self.url_normalized = self.class.normalized_url(url)
    end

    # Callback to modify url_langcode
    #
    def normalize_url_langcode
      self.url_langcode = url_langcode.strip.downcase if url_langcode
    end

    # Should have a valid host with/without a scheme
    def url_validity
      if ModuleUrlUtil.scheme_and_uri_string(url).first.blank?
        errors.add(:url, " url does not appear to be a valid URI")
      end
    end

end
