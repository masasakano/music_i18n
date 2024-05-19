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

  # NOTE: see below validate_translation_callback

  validates_presence_of :artist_id, if: :themselves, message: "can't be blank when 'themselves?' is checked."

  # Only 1 ChannelOwner has themselves==true per the parent Artist.
  validate :sole_themselves_per_artist?

  # If themselves==true, a valid unsaved_translations must be supplied.
  validate :presence_of_unsaved_translations, if: :themselves  # if: [:themselves, :artist_id]  # not works?

  before_create     :set_create_user       # This always sets non-nil weight. defined in /app/models/concerns/module_whodunnit.rb
  before_save       :set_update_user       # defined in /app/models/concerns/module_whodunnit.rb

  belongs_to :artist, optional: true
  belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
  belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false
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
    translations.reset
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
  # If themselves==true, a valid unsaved_translations, which are basically
  # identical to those of the parent Artist for all the languages, must be supplied.
  def presence_of_unsaved_translations
    return if !artist
    msg_trans = (new_record? ? "unsaved_" : "")+"translations"
    all_lcodes = []
    artist.best_translations.each_pair do |langcode, tra|
      all_lcodes << langcode
      cands = (new_record? ? unsaved_translations : translations).find_all{|et| langcode == et.langcode}
      if 1 != cands.size
        errors.add :base, "must have exact #{msg_trans} corresponding to the parent Artist but has zero (or multiple) Translations for language #{langcode.inspect}"
        return
      end

      if !Translation.identical_contents?(tra, cands.first)
        errors.add :base, "has a different #{msg_trans} from the parent Artist's counterpart for language #{langcode.inspect}"
        return
      end
    end

    if all_lcodes.sort.map(&:to_s) != (new_record? ? unsaved_translations : translations).map{|i| i.langcode}.sort.map(&:to_s)
      errors.add :base, "has the #{msg_trans} with a langcode absent in the parent Artist's counterparts"
      return
    end
  end
  private :presence_of_unsaved_translations

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
    arret = validate_translation_neither_title_nor_alt_exist(trans)  # defined in BaseWithTranslation

    if !themselves 
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

