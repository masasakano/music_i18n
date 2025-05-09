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
#  artist_id                                  :bigint
#  create_user_id                             :bigint
#  update_user_id                             :bigint
#
# Indexes
#
#  index_channel_owners_on_artist_id       (artist_id)
#  index_channel_owners_on_create_user_id  (create_user_id)
#  index_channel_owners_on_themselves      (themselves)
#  index_channel_owners_on_update_user_id  (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id)
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
class ChannelOwner < BaseWithTranslation
  # handles create_user, update_user attributes
  include ModuleCreateUpdateUser
  #include ModuleWhodunnit # for set_create_user, set_update_user

  include ModuleCommon # for ChannelOwner.new_unique_max_weight

  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  # defines +self.class.primary+
  include ModulePrimaryArtist

  PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym
  attr_accessor PARAMS_KEY_AC  # :artist_with_id

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
  # Disabled because a custom +validate_translation_callback+ is implemented instead.
  TRANSLATION_UNIQUE_SCOPES = :disable

  validates_presence_of :artist_id, if: :themselves, message: " can't be blank when 'themselves?' is checked."

  # Only 1 ChannelOwner has themselves==true per the parent Artist.
  validate :sole_themselves_per_artist?

  # If themselves==true, a valid unsaved_translations must be supplied.
  validate :presence_of_valid_translations, if: :themselves  # if: [:themselves, :artist_id]  # not works?

  # Translation has to be unique per "themselves"
  validate :combination_themselves_unique_translation

  belongs_to :artist, optional: true
  has_many :channels, -> {distinct}, dependent: :restrict_with_exception  # dependent is a key / Basically this should not be easily destroyed - it may be merged instead.
  has_many :harami_vids, -> {distinct}, through: :channels

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = {
    "ja" => ['不明のチャンネル主'],
    "en" => ['Unknown channel owner'],
    "fr" => ['Propriétaire de chaine inconnu'],
  }.with_indifferent_access

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s
  include ModuleModifyInspectPrintReference
  redefine_inspect

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

  # (Re)set artist_id
  #
  # The record is not saved, yet. However, Translation-s are updated!
  # The caller may enclose the calling routine inside Transaction.
  #
  # @param artist [Artist]
  # @param force: [Boolean] if true, {#themselves} is set true regardless of the current value.
  def reset_to_artist(artist, force: false)
    self.artist = artist
    self.themselves = true if force # This should already be set.
    synchronize_translations_to_artist
  end

  # @return [Array<Translations>] initialized (unsaved) Translations with identical contents to the best ones of the given Artist
  def initialize_from_artist_translations
    return if !artist
    artist.best_translations.values.map{ |tra|
      Translation.new tra.hs_key_attributes
    }
  end

  # For a new record, set (actually replace) {#unsaved_translations} based on Artist
  #
  def set_unsaved_translations_from_artist
    raise if !new_record?
    return unsaved_translations if !artist

    unsaved_translations.replace( initialize_from_artist_translations )
  end

  # For update, this method synchronizes translations with those of the artist
  #
  # This method actually updates or creates a Translation.
  #
  # *WARNING*: The caller should enclose the call to this method with transaction for update.
  #
  def synchronize_translations_to_artist
    raise if new_record?
    return if !artist

    valid_tras = []
    artist.best_translations.each_pair do |lc_art, tra_art|
      if (tra=best_translations[lc_art])
        tra.update!(tra_art.hs_key_attributes)
      else
        translations << (tra=Translation.new(tra_art.hs_key_attributes))
        tra.reload
      end
      valid_tras << tra
    end

    # Now destroy surplus Translations if there is any.
    # no need of reload-ing here
    translations.each do |tra|
      tra.destroy! if !valid_tras.include?(tra)
    end

    update_user_for_equivalent_artist
    translations.reset
  end

  # Adjusts each Translation's update_user and updated_at
  #
  # @note updated_at is adjusted while created_at stays — meaning it makes
  #   updated_at < created_at because the Translation for ChannelOwner
  #   was newly created whereas the corresponding Translation for Artist
  #   was last updated (long time) before.
  #
  # @return [void]
  def update_user_for_equivalent_artist
    return if !artist
    translations.reset
    artist.best_translations.each_pair do |lc, etrans|
      hs = %w(update_user_id updated_at).map{ |metho|
        [metho, etrans.send(metho)]
      }.to_h
      best_translations[lc].update_columns(hs)  # skips all validations AND callbacks
    end
  end

  ###################

  # Custom validation
  #
  # No two ChannelOwner-s with themselves==true can have a common parent Artist
  def sole_themselves_per_artist?
    if themselves && artist && self.class.where(artist_id: artist.id, themselves: true).where.not(id: id).exists?
      errors.add :themselves, "cannot have themselves==true with this Artist because another ChannelOwner is alreay defined for them."
    end
  end
  private :sole_themselves_per_artist?

  # Custom validation
  #
  # If themselves==true, a valid (unsaved_)translations, which are basically
  # identical to those of the parent Artist for all the languages, must be supplied.
  def presence_of_valid_translations
    return if !artist
    msg_trans = (new_record? ? "unsaved_" : "")+"translations"
    artrans = (new_record? ? unsaved_translations : translations)
    all_lcodes = []
    artist.best_translations.each_pair do |langcode, tra|
      all_lcodes << langcode
      cands = artrans.find_all{|et| langcode == et.langcode}
      if 1 != cands.size
        s_num = ((0 == cands.size) ? "zero" : "multiple")
        errors.add :base, "must have exact #{msg_trans} corresponding to the parent Artist but has #{s_num} Translations for language #{langcode.inspect}"
        return
      end

      if !Translation.identical_contents?(tra, cands.first)
        errors.add :base, "has a different #{msg_trans} from the parent Artist's counterpart for language #{langcode.inspect}"
        return
      end
    end

    if all_lcodes.sort.map(&:to_s) != artrans.map{|i| i.langcode}.sort.map(&:to_s)
      errors.add :base, "has the #{msg_trans} with a langcode absent in the parent Artist's counterparts"
      return
    end
  end
  private :presence_of_valid_translations

  # This is relevant on update, when themselves is changed (because other callbacks take care of create)
  def combination_themselves_unique_translation
    msg2add =
      if themselves_changed?
        " So, you cannot alter 'themselves?' status - you may consider merging ChannelOwners or associate this to another Artist first."
      else
        " So, you may associate this ChannelOwner to another Artist."
      end
    col = (themselves_changed? ? :themselves : PARAMS_KEY_AC)

    translations.each do |trans|
      armsg = validate_translation_callback(trans)
      next if armsg.empty?
      armsg.each do |em|
        errors.add col, em+msg2add
      end
    end
  end
  private :combination_themselves_unique_translation

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  #
  # First, a Translation must have either title or alt_title.
  # Second, the Translation of self with themselves==false has to be unique among
  # other records with themselves==false.
  # (We ignore those with themselves==true because Artists can have identical names
  # as long as they have different Place or Birthday.)
  #
  # These are the only validations for update.
  #
  # For create, the Translation so as to allow an admin to manage a Translation,
  # in particular for editing an existing Translation.
  #
  # Controllers should take care of the restrictions.
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(trans)
    arret = []
    if find_all_same_trans(trans).exists?
      return [" ChannelOnwer with an equivalent Translation "+(themselves ? "for the same Artist" : "among those related to no Artists")+" already exists (language=#{trans.langcode})."]
    end

    if !themselves && artist
      hstmp = %w(title alt_title langcode).map{ |ek|
        ["translations."+ek, trans.send(ek)]
      }.to_h
      if self.class.joins(:translations).where(themselves: false).where(hstmp).exists?
        arret << " is not allowed as another #{self.class.name} already has it"
        return arret
      end
    end

    return arret if !trans.new_record?
    return arret if !(themselves && artist)

    # Now, guaranteed it is for create and ChannelOwner has a parent Artist
    # A new Translation can be added only for initialization, i.e, when
    #  (1) the parent Artist has the corresponding-language Translation,
    #  (2) yet self does not have one, and
    #  (3) all the main columns are identical to the parent Artist's Translation.

    lcode = trans.langcode.to_s

    if best_translations[lcode]
      arret << "cannot be added as the corresponding [#{lcode}] Translation for the parent Artist (#{artist.best_translations[lcode].inspect}) already exists."
      return arret
    end

    art_trans = artist.best_translations[lcode]
    if !art_trans
      arret << "cannot be added as the parent Artist does not have a Translation for langcode=#{lcode.inspect}"
      return arret
    end

    hs_templates = art_trans.hs_key_attributes

    hs_templates.each_pair do |ecol, eaval|
      if (val=trans.send(ecol)) != eaval
        arret << "has a different #{ecol.to_s}=#{val.inspect} from the parent Artist's Translation (#{eaval.inspect})."
        return arret
      end
    end

    return arret
  end

  # Find all ChannelOwner with the same themselves and one of translations  (no distinct is applied)
  #
  # This also checks with self's other translations.
  #
  # @param trans [Translation]
  # @return [ActiveRecord::Relation]
  def find_all_same_trans(trans)
    base = self.class.joins(:translations).where(themselves: themselves).where.not("translations.id" => trans.id)
    rela = base
    cols = %w(langcode title alt_title)
    hs = trans.attributes.slice(*(cols))
    hs1 = hs.map{|ek, ev| ["translations."+ek, ev]}.to_h
    hs2 = hs.merge({"title" => hs["alt_title"], "alt_title" => hs["title"]}).map{|ek, ev| ["translations."+ek, ev]}.to_h  # title <=> alt_title
    rela = rela.where(hs1).or(base.where(hs2))
    rela
  end
end

class << ChannelOwner
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  #
  # If artist and themselves are specified, the specified title etc are ignored.
  #
  # ChannelOwner and associated Artist are both reloaded.
  def create_basic!(*args, **kwds, &blok)
    record = initialize_basic(*args, **kwds, &blok).tap{|obj| obj.save!}
    record.artist.reload if record.artist
    record.reload        if record.artist || kwds.with_indifferent_access["langcode"].present?
    record
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  #
  # If artist and themselves are specified, the specified title etc are ignored.
  def initialize_basic(*args, artist: nil, artist_id: nil, **kwds, &blok)
    artist, artist_id = artist_artist_id(artist, artist_id)
    record = initialize_basic_bwt(*args, artist_id: artist_id, **kwds, &blok)

    if record.themselves && artist_id.present?
      record.set_unsaved_translations_from_artist
    end
    record
  end

  # @return [Array] of Artist and artist_id (Integer or String). Both may be blank.  Artist may be nil even if artist_id is present?
  def artist_artist_id(artist, artist_id)
    if artist_id.present?
      warn "Both artist and artist_id is given in a duplicated way in #{name}.#{__method__}" if artist.present?
    else
      artist_id = artist.id if artist
    end
    [artist, artist_id]
  end
  private :artist_artist_id
end

