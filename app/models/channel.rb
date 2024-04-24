# coding: utf-8
# == Schema Information
#
# Table name: channels
#
#  id                  :bigint           not null, primary key
#  note                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  channel_owner_id    :bigint           not null
#  channel_platform_id :bigint           not null
#  channel_type_id     :bigint           not null
#  create_user_id      :bigint
#  update_user_id      :bigint
#
# Indexes
#
#  index_channels_on_channel_owner_id     (channel_owner_id)
#  index_channels_on_channel_platform_id  (channel_platform_id)
#  index_channels_on_channel_type_id      (channel_type_id)
#  index_channels_on_create_user_id       (create_user_id)
#  index_channels_on_update_user_id       (update_user_id)
#  index_unique_all3                      (channel_owner_id,channel_type_id,channel_platform_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (channel_owner_id => channel_owners.id)
#  fk_rails_...  (channel_platform_id => channel_platforms.id)
#  fk_rails_...  (channel_type_id => channel_types.id)
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
class Channel < BaseWithTranslation
  include ModuleWhodunnit # for set_create_user, set_update_user

  include ModuleCommon # for ChannelOwner.new_unique_max_weight

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

  ### This validation is NOT activated so a same Translation is allowed as long as the 3 unique parameters are accepted.
  #def validate_translation_callback(record)
  #  validate_translation_neither_title_nor_alt_exist(record)  # defined in BaseWithTranslation
  #end

  belongs_to :channel_owner
  belongs_to :channel_type
  belongs_to :channel_platform
  has_many :harami_vids, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.

  before_create     :set_create_user       # This always sets non-nil weight. defined in /app/models/concerns/module_whodunnit.rb
  before_save       :set_update_user       # defined in /app/models/concerns/module_whodunnit.rb

  belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
  belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false
  #has_many :channels, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.

  #validates_presence_of :channel_owner, :channel_type, :channel_platform  # unnecessary as automatically checked.
  validates :channel_owner, uniqueness: { scope: [:channel_type, :channel_platform] }

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のチャンネル'],
    "en" => ['Unknown channel'],
    "fr" => ['Chaine inconnue'],
  }.with_indifferent_access

  # @return [Channel]
  def self.primary
    self.find_by(
      channel_type_id:     ChannelType.find_by(mname: :main).id,
      channel_platform_id: ChannelPlatform.find_by(mname: :youtube).id,
      channel_owner_id:    ChannelOwner.primary.id,
    )
  end
end

