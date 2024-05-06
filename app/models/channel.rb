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

  validate :valid_present_unsaved_translations, on: :create  # @unsaved_translations must be defined and valid. / defined in BaseWithTranslation

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のチャンネル'],
    "en" => ['Unknown channel'],
    "fr" => ['Chaine inconnue'],
  }.with_indifferent_access

  # @return [Channel]
  def self.primary
    self.find_by(
      channel_type_id:     ChannelType.default(:HaramiVid).id,
      channel_platform_id: ChannelPlatform.default(:HaramiVid).id,
      channel_owner_id:    ChannelOwner.primary.id,
    )
  end

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # For now, this is just an alias.
  #
  # @option context [Symbol, String]
  # @option place: [Place]
  # @return [Channel]
  def self.default(context=nil, place: nil)
    primary
  end

  # Initial (unsaved) Translation Array
  #
  # One of them has is_orig=true and the others, is_orig=false.
  #
  # @return [Array<Translation>] so this can be directly fed to unsaved_translations
  def def_initial_translations
    transs = I18n.available_locales.map{|lc| def_initial_trans(langcode: lc)}.compact
    if !transs.empty?
      transs[0].is_orig = true
      transs[1..-1].each do |tra|
        tra.is_orig = false 
      end if transs.size > 1
      return transs 
    end

    # fallback... (only a single Translation is created.
    # NOTE: If you ever thihnk of creating multiple translations, some of their langcodes may become the same (due to fallback) and hence there would be a risk of unique-validation failure. Be careful.
    tra = def_initial_trans(langcode: I18n.locale, force: true)
    raise "(#{File.basename __FILE__}) Seemingly the translations in any of channel_owner channel_platform channel_type in any languages are completely blank. Strange." if tra.blank?
    tra.is_orig = true
    [tra]
  end


  # Returns an unsaved Translation of a specified language
  #
  # {Translation#translatable} is not set.  Nor {Translation#is_orig}.
  #
  # @param [Boolean] if true (Def: false), a new Translation is almost always created, falling-back to
  #   language; only the time nis is returned is when all three are completely nil in any languages
  #   (meaning they all are invalid!).
  # @return [Translation, NilClass] A default (unsaved) Translation when a new Channel is created.
  #    returns nil if one of three dependents does not have a Translation for the specified langcode.
  def def_initial_trans(lcode=nil, langcode: I18n.locale, force: false)
    lcode ||= langcode
    arstr = %w(channel_owner channel_platform channel_type).map{|model|
      if force
        send(model).title_or_alt(langcode: lcode, lang_fallback_option: :either, str_fallback: "")
      else
        send(model).title(langcode: lcode)
      end
    }
    return nil if arstr.any?{|i| i.blank?} && !force
    return nil if arstr.all?{|i| i.blank?}  # In an extremely unlikely case of all of them being blank, nil is returned regardless of the force option.

    tit = sprintf "%s /%s (%s)", *arstr
    lcode2set = (contain_asian_char?(tit) ? "ja" : lcode)  # to avoid potential Asian-char validation failure.
    Translation.new(title: tit, langcode: lcode2set)
  end


  ######################## callbacks #######################

  ## Callback invoed by {BaseWithTranslation#save_unsaved_translations}
  ## which is an after_create callback.
  ##
  ## This ensures a newly created record always has a {Translation}
  ## (because creating users may not care!)
  ##
  ## @return [self] self is NOT reloaded after saving Translations.
  #def fallback_non_existent_unsaved_translations
  #  return if self.new_record?  # self shoud not be a new record!

  #  def_initial_translations.each do |et|
  #    self.translations << et
  #  end
  #  self
  #end

end

