# coding: utf-8
# == Schema Information
#
# Table name: channel_types
#
#  id                                                 :bigint           not null, primary key
#  mname(machine name (alphanumeric characters only)) :string           not null
#  note                                               :text
#  weight(weight for sorting within this model)       :integer          default(999), not null
#  created_at                                         :datetime         not null
#  updated_at                                         :datetime         not null
#  create_user_id                                     :bigint
#  update_user_id                                     :bigint
#
# Indexes
#
#  index_channel_types_on_create_user_id  (create_user_id)
#  index_channel_types_on_mname           (mname) UNIQUE
#  index_channel_types_on_update_user_id  (update_user_id)
#  index_channel_types_on_weight          (weight)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
class ChannelType < BaseWithTranslation
  include ModuleWhodunnit # for set_create_user, set_update_user

  include ModuleCommon # for ChannelType.new_unique_max_weight

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
  #TRANSLATION_UNIQUE_SCOPES = :default

  before_create     :set_create_user       # This always sets non-nil weight. defined in /app/models/concerns/module_whodunnit.rb
  before_save       :set_update_user       # defined in /app/models/concerns/module_whodunnit.rb

  belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
  belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false
  has_many :channels, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.

  validates_presence_of   :mname
  validates_uniqueness_of :mname
  validates_presence_of   :weight  # NOTE: At the DB level, a default is defined.
  #validates_uniqueness_of :weight  # No DB-level constraint, either
  validates_numericality_of :weight
  validates :weight, :numericality => { :greater_than_or_equal_to => 0 }

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のチャンネル種類'],
    "en" => ['Unknown channel type'],
    "fr" => ['Type de chaine inconnue'],
  }.with_indifferent_access

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @return [EventItem, Event]
  def self.default(context=nil, place: nil)
    case context.to_s.underscore.singularize
    when *(%w(harami_vid harami1129))
      ret = self.find_by(mname: "main")
      return ret if ret
      logger.warn("WARNING(#{File.basename __FILE__}:#{__method__}): Failed to identify the default #{self.class.name}!")
    end

    self.unknown
  end

end
