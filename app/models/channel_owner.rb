# coding: utf-8
# == Schema Information
#
# Table name: channel_owners
#
#  id                                         :bigint           not null, primary key
#  note                                       :text
#  themselves(true if identical to an Artist) :boolean          default(FALSE)
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  create_user_id                             :bigint
#  update_user_id                             :bigint
#
# Indexes
#
#  index_channel_owners_on_create_user_id  (create_user_id)
#  index_channel_owners_on_themselves      (themselves)
#  index_channel_owners_on_update_user_id  (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
class ChannelOwner < BaseWithTranslation
  include ModuleWhodunnit # for set_create_user, set_update_user

  include ModuleCommon # for ChannelOwner.new_unique_max_weight

  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  # defines +self.class.primary+
  include ModulePrimaryArtist

  attr_accessor :artist_with_id

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  #
  # Basically, Translations must be unique.
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    validate_translation_neither_title_nor_alt_exist(record)  # defined in BaseWithTranslation
  end

  before_create     :set_create_user       # This always sets non-nil weight. defined in /app/models/concerns/module_whodunnit.rb
  before_save       :set_update_user       # defined in /app/models/concerns/module_whodunnit.rb

  belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
  belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false
  has_many :channels, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のチャンネル主'],
    "en" => ['Unknown channel owner'],
    "fr" => ['Propriétaire de chaine inconnu'],
  }.with_indifferent_access

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # This class also defines {ChannelOwner.primary} by including ModulePrimaryArtist
  #
  # @option context [Symbol, String]
  # @option place: [Place]
  # @return [ChannelOwner]
  def self.default(context=nil, place: nil)
    # case context.to_s.underscore.singularize
    # when "harami_vid", "harami1129"
    # end
    self.select_regex(:titles, /^(ハラミちゃん|HARAMIchan|Harami-chan)$/i, sql_regexp: true).first || self.unknown
  end

end
