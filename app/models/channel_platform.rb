# coding: utf-8
# == Schema Information
#
# Table name: channel_platforms
#
#  id                                                 :bigint           not null, primary key
#  mname(machine name (alphanumeric characters only)) :string           not null
#  note                                               :text
#  created_at                                         :datetime         not null
#  updated_at                                         :datetime         not null
#  create_user_id                                     :bigint
#  update_user_id                                     :bigint
#
# Indexes
#
#  index_channel_platforms_on_create_user_id  (create_user_id)
#  index_channel_platforms_on_mname           (mname) UNIQUE
#  index_channel_platforms_on_update_user_id  (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
class ChannelPlatform < BaseWithTranslation
  # Class-method helpers
  include ClassMethodHelper

  include ModuleWhodunnit # for set_create_user, set_update_user

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

  before_create     :set_create_user       # This always sets non-nil weight. defined in /app/models/concerns/module_whodunnit.rb
  before_save       :set_update_user       # defined in /app/models/concerns/module_whodunnit.rb

  belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
  belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false
  has_many :channels, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.

  validates_presence_of   :mname
  validates_uniqueness_of :mname

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のプラットフォーム'],
    "en" => ['Unknown platform'],
    "fr" => ['Estrade inconnue'],
  }.with_indifferent_access

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @option place: [Place]
  # @return [ChannelPlatform]
  def self.default(context=nil, place: nil)
    case context.to_s.underscore.singularize
    when *(%w(harami_vid harami1129))
      ret = self.find_by(mname: "youtube")
      return find_default(ret)   # may raise an Exception
    end

    self.unknown
  end

  # true if YouTube
  def youtube?
    "youtube" == (mname && mname.to_s.downcase)
  end
end
