# coding: utf-8
# == Schema Information
#
# Table name: channels
#
#  id                                                                     :bigint           not null, primary key
#  id_at_platform(Channel-ID at the remote platform)                      :string
#  id_human_at_platform(Human-readable Channel-ID at remote prefixed <@>) :string
#  note                                                                   :text
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  channel_owner_id                                                       :bigint           not null
#  channel_platform_id                                                    :bigint           not null
#  channel_type_id                                                        :bigint           not null
#  create_user_id                                                         :bigint
#  update_user_id                                                         :bigint
#
# Indexes
#
#  index_channels_on_channel_owner_id      (channel_owner_id)
#  index_channels_on_channel_platform_id   (channel_platform_id)
#  index_channels_on_channel_type_id       (channel_type_id)
#  index_channels_on_create_user_id        (create_user_id)
#  index_channels_on_id_at_platform        (id_at_platform)
#  index_channels_on_id_human_at_platform  (id_human_at_platform)
#  index_channels_on_update_user_id        (update_user_id)
#  index_unique_all3                       (channel_owner_id,channel_type_id,channel_platform_id) UNIQUE
#  index_unique_channel_platform_its_id    (channel_platform_id,id_at_platform) UNIQUE
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
  # handles create_user, update_user attributes
  include ModuleCreateUpdateUser
  #include ModuleWhodunnit # for set_create_user, set_update_user

  # polymorphic many-to-many with Url
  include Anchorable

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

  # id in link_to_channel in ApplicationHelper for each of attribute keywords.
  LINK_TO_CHANNEL_KINDS = {
    id_at_platform: "id",
    id_human_at_platform: "handle",
  }.with_indifferent_access

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  # No Translation-related model-specific validations for Channel. See the comment for the callback below.
  TRANSLATION_UNIQUE_SCOPES = :disable

  ### This validation is NOT activated so a same Translation is allowed as long as the 3 unique parameters are accepted.
  #def validate_translation_callback(record)
  #  validate_translation_unique_title_alt(record)  # defined in BaseWithTranslation
  #end

  belongs_to :channel_owner
  belongs_to :channel_type
  belongs_to :channel_platform
  has_many :harami_vids, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.
  has_many :harami1129s, through: :harami_vids, dependent: :restrict_with_exception  # I think dependent is redundant

  # callback to make sure id_human_at_platform has a prefix of "@"
  before_validation :ensure_atmark_id_human_for_validation

  #has_many :channels, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.

  #validates_presence_of :channel_owner, :channel_type, :channel_platform  # unnecessary as automatically checked.
  validates :channel_owner, uniqueness: { scope: [:channel_type, :channel_platform] }

  validates :id_at_platform,       uniqueness: { scope: [:channel_platform] }, allow_nil: true
  validates :id_at_platform,       length: {minimum: 3}, allow_nil: true  # 3 is rather random...
  validates :id_at_platform,       format: {with: /\A[[:ascii:]]+\z/i}, allow_nil: true
  validates :id_at_platform,       format: {without: /[\s\/]/i},          allow_nil: true

  validates :id_human_at_platform, uniqueness: { scope: [:channel_platform] }, allow_nil: true  # No DB-level constraint.
  validates :id_human_at_platform,       length: {minimum: 3}, allow_nil: true  # 3 is rather random...
  #validates :id_human_at_platform,       format: {with: /\A[[:ascii:]]+\z/i}, allow_nil: true  # Asian characters are allowed on Youtube (but not on Twitter/X)
  validates :id_human_at_platform,       format: {without: /[\s]|\A.+@/i},    allow_nil: true
  # Note that if (channel_platform == :other) and id_at_platform-s agree, it would raise a DB-level error(!). For Channels with (channel_platform == :other), you should leave id_at_platform-s blank and instead record them in note if need be (though there is no application-level check for this).

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
    # NOTE: If you ever think of creating multiple translations, some of their langcodes may become the same (due to fallback) and hence there would be a risk of unique-validation failure. Be careful.
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
  #   language; only the time nil is returned is when all three are completely nil in any languages
  #   (meaning they all are invalid!).
  # @return [Translation, NilClass] A default (unsaved) Translation when a new Channel is created.
  #    returns nil if one of three dependents does not have a Translation for the specified langcode.
  def def_initial_trans(lcode=nil, langcode: I18n.locale, force: false)
    tit = self.class.def_initial_trans_str(
      lcode,
      channel_owner:    channel_owner,
      channel_type:     channel_type,
      channel_platform: channel_platform,
      langcode: langcode,
      force: force
    )
    lcode ||= langcode

    # lcode = (contain_asian_char?(tit) ? "ja" : lcode)  # to avoid potential Asian-char validation failure.
    return nil if !%w(ja ko zh).include?(lcode.to_s[0..1]) && contain_asian_char?(tit)
    Translation.new(title: tit, langcode: lcode)
  end


  # Returns a String (with singleton-method lcode set) for a specified or its default language
  #
  # core method of Channel#def_initial_trans
  #
  # NOTE that the +lcode+ set for the returned String is irrelevant to the given langcode.
  # They should usually agree, but in some cases they don't.  For example,
  # if langcode="kr" is specified and none of the given models have Korean Translations,
  # +returned_str.lcode+ is different from "kr".
  # Also note that it is possible that langcode-s for the three component do not
  # totally agree, in which case +lcode+ is one of them, maybe "ja".
  #
  # Even if lcode="en" for the returned String, it may still contain Asian characters
  # as this method does not check the contents.  Do your own check with +contain_asian_char?+
  # if necessary (defined in ModuleCommon).
  #
  # @param [Boolean] if true (Def: false), a new Translation is almost always created, falling-back to
  #   language; only the time nil is returned is when all three are completely nil in any languages
  #   (meaning they all are invalid!).
  # @return [String, NilClass] A String with {String#lcode} set when a new Channel is created.
  #    returns nil if one of three dependents does not have a Translation for the specified langcode.
  def self.def_initial_trans_str(lcode=nil, channel_owner:, channel_type:, channel_platform:, langcode: I18n.locale, force: false)
    lcode ||= langcode
    arstr = [channel_owner, channel_platform, channel_type].map{|model|
      if force
        model.title_or_alt(langcode: lcode, lang_fallback_option: :either, str_fallback: "")
      else
        model.title(langcode: lcode)
      end
    }
    return nil if arstr.any?{|i| i.blank?} && !force
    return nil if arstr.all?{|i| i.blank?}  # In an extremely unlikely case of all of them being blank, nil is returned regardless of the force option.

    retstr = sprintf "%s / %s (%s)", *arstr

    lcode_new = arstr.map(&:lcode).sort{ |a, b|
      if "ja" == a
        -1
      elsif "ja" == b
        1
      else
        0
      end
    }.first
    
    retstr.instance_eval{singleton_class.class_eval { attr_accessor "lcode" }}
    retstr.lcode = lcode_new
    retstr
  end

  # true if on YouTube
  def on_youtube?
    channel_platform.youtube?
  end

  ######################## callbacks #######################

  # before_validation callback
  #
  # Non-blank {#id_human_at_platform} is guaranteed to have the prefix +@+
  def ensure_atmark_id_human_for_validation
    self.id_human_at_platform.sub!(/\A@?/, "@") if id_human_at_platform.present?
  end

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

class << Channel
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Finds a combination that does not exist (to circumvent a validation violation).
  def _find_creatable_channel_combinations
    ChannelOwner.ids.each do |owner|
      ChannelPlatform.ids.each do |platform|
        ChannelType.ids.each do |type|
          hstry = {
            channel_owner_id: owner,
            channel_platform_id: platform,
            channel_type_id: type
          }
          return hstry if !Channel.find_by(**hstry)
        end
      end
    end 
  end
  private :_find_creatable_channel_combinations
  
  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, **kwds, &blok)
    hsprm = _find_creatable_channel_combinations
    create_basic_bwt!(*args, **(hsprm.merge(kwds)), &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  def initialize_basic(*args, **kwds, &blok)
    hsprm = _find_creatable_channel_combinations
    initialize_basic_bwt(*args, **(hsprm.merge(kwds)), &blok)
  end
end

