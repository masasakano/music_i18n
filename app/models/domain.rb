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
  belongs_to :domain_title

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
  validates_numericality_of :weight, allow_nil: true
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # @param reload [void] Always ignored. Just for conistency with ModuleUnknown
  def self.unknown(reload: nil)
    find_by(domain: UNKNOWN_TITLE) 
  end

  def unknown?
    self == self.class.unknown
  end

  private

    # Callback
    #
    # Prefix "https" is allowed, but removed on save.
    # Port number is allowed, but removed on save.
    # A trailing forward slash is allowed, but removed on save.
    def normalize_domain
      if /\A\s*(?:(?:https?|file):\/\/)?(#{REGEXP_DOMAIN_CORE_STR})(?::[0-9]{1,5})?(?:\/)?\s*\z/ix =~ domain
        self.domain = $1.downcase
      end
    end
end
