# coding: utf-8
# == Schema Information
#
# Table name: channel_owners(Owner of a Channel)
#
#  id                                         :bigint           not null, primary key
#  note                                       :text
#  orig_locale(locale of original title)      :string(2)
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

  # for destroyable?
  include ModuleDestroyable

  # defines +self.class.primary+
  include ModulePrimaryArtist

  PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym
  attr_accessor PARAMS_KEY_AC  # :artist_with_id

  # Minimum requirements for editing Translation (see BaseWithTranslation).
  TRANSLATION_EDITABLE_IF_AT_LEAST = :editor?

  # For the translations to be unique (required by BaseWithTranslation).
  #
  # See also {TRANSLATION_UNIQUE_SCOPES}
  MAIN_UNIQUE_COLS = [:artist_id]

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of :title and :alt_title.
  # Alternatively you may set +:disable+ ant instead write a custom +validate_translation_callback+
  # (This class does have +validate_translation_callback+ ...)
  # Multiple ChannelOwner-s can have the same Translations if they belongs_to
  # separate Artists.
  TRANSLATION_UNIQUE_SCOPES = %w(artist_id)

  # Optional constant for a subclass of {BaseWithTranslation}, when TRANSLATION_UNIQUE_SCOPES is defined.
  # If true (Default), a word used in +title+ should not appear even in +alt_title+ and vice versa.
  # If false, the uniquewness is based on the combination of both.  For the sub-classes where many editors may work on,
  # false would be more appropriate so that other editors can propose similar but partially different Translations.
  TRANSLATION_STRICTLY_UNIQUE_TITLES = false

  validates_presence_of :artist_id, if: :themselves, message: " can't be blank when 'themselves?' is checked."

  validate :no_artist_no_sync, unless: :themselves

  # Only 1 ChannelOwner has themselves==true per the parent Artist. (Actually, it is now :has_one for Artist)
  validate :sole_themselves_per_artist?

  validate :orig_locale_must_match_artist, if: -> { themselves? && artist.present? && !skip_orig_locale_validation }  # In fact, artist.present? is guaranteed if themselves? (see a validation above)

  validate :synced_all_translations, if: -> { themselves? && artist.present? && !skip_orig_locale_validation }

  # If themselves==true, a valid unsaved_translations must be supplied.
  validate :presence_of_valid_translations, if: -> { themselves? && artist.present? && !skip_orig_locale_validation }

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

  # essential for ModuleDestroyable
  DEPENDENT_CHILDREN = [:channels]

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

  # Overwriting the parent method.
  #
  # Child of this class may overwrite this method, e.g., {ChannelOwner}
  # some of instances of which have synchronized Translations with their parent Artist
  #
  # @return [Boolean] true if any of {#translations} can be updated
  def translation_updatable_at_all?
    !(themselves && artist)
  end

  # Resets (some attributes of) self and {#translations} according to {#artist} already set
  #
  # Basically, Controller SHOULD always call this method before validation,
  # regardless of {#artist_id} and {#themselves} in params.
  #
  # Accordingly, this is called also from /db/seeds/channel_owners.rb
  #
  # @param artist [Artist]
  # @param force: [Boolean] if true, {#themselves} is set according to {#artist}
  # @return [void]
  def reset_by_artist(force: false)
    self.themselves = !!artist if force
    unsaved_translations.clear if themselves && unsaved_translations.present?

    if translation_updatable_at_all?
      nullify_sync_translations
    else  ## e.g., if artist && themselves
      synchronize_translations_to_artist
    end
  end

  # (Re)set artist_id
  #
  # The record is not saved, yet, with in-memory Translations.
  # The caller may enclose the calling routine inside Transaction.
  #
  # @param artist [Artist]
  # @param force: [Boolean] if true, {#themselves} is set true regardless of the current value.
  def reset_to_artist(artist, force: false)
    self.artist = artist
    reset_by_artist(force: force)
  end

  # OBSOLETE !!!!!!!!!!!
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

    translations.clear
    artist.translations.each do |etra|
      tra = etra.dup
      tra.translatable = nil
      translations << tra
    end
    self.orig_locale = artist.orig_locale
    unsaved_translations.replace( [] ) if @unsaved_translations.present?
  end

  # This method synchronizes {#orig_locale} and {#translations} with those of the {#artist}
  #
  # This method basically builds in-memory associated Translation,
  # including mark-for-destroy, whether for :create or :update, so that
  # the child Translation-s of self will be aligned to those of parent Artist
  # when self is saved.
  #
  # *Note*:
  # This method used to actually update or create Translation-s, and therefore,
  # the caller MUST have enclosed the call to this method with transaction for update.
  #
  # @note If a new Translation for ChannelOwner is created (not updated),
  #   its timestamps will be +updated_at < created_at+
  #   See {#_hash_for_synchronization} for justification and detail.
  #
  # @return [void]
  def synchronize_translations_to_artist
    # raise if new_record?
    return if !artist

    self.orig_locale = artist.orig_locale

    ### to completely reset...
    ### NOTE: this would not work well if there is a racing condition where
    ###   you destroy one and create an almost identical one; e.g.,
    ###   if you associate a Translation, decouple it, and re-associate it.
    # translations.each(&:mark_for_destruction)

    matched_children = Set.new

    artist.translations.each do |art_tran|
      child = find_child_translation_of(art_tran, excludes: matched_children, strict: false)

      if child
        # Updates existing record in-place & attach/confirm sync_parent
        child.assign_attributes(
          _hash_for_synchronization(art_tran, to_update: true)  # sets title, ..., sync_parent, update_user_id
        )
        child.syncing_from_parent = true  # mark to bypass a Translation validation (which is to prevent editing Translation of ChannelOwner having a parent Artist)
        matched_children.add(child)
      else
        # Builds new child translation linked to parent
        new_child = translations.build(
          _hash_for_synchronization(art_tran, to_update: false)
        )
        new_child.syncing_from_parent = true  # mark to bypass a Translation validation
        matched_children.add(new_child)
      end
    end  # artist.translations.each do |art_tran|

    # Mark orphan child translations for destruction
    active_translations.each do |c|
      unless matched_children.include?(c)
        c.sync_translation_id = nil  # or "tran.sync_parent=nil";  Without this, destroy-validation would prevent destroying (because the Translation has a parent Translation), raising ActiveRecord::RecordNotDestroyed
        c.mark_for_destruction 
      end
    end
  end

    # @note For :create (but NOT for :update), updated_at is manualy set
    #   while created_at will be set in default (the current time), meaning this makes
    #   updated_at < created_at because the Translation(s) for ChannelOwner
    #   was newly created whereas the corresponding Translation for Artist
    #   must have been last updated some (long) time ago.
    #
    # @param trans [Translation] parent Artist's Translation
    # @return [Hash] build from trans to create/update ChannelOwner's Translation by synchronization
    def _hash_for_synchronization(trans, to_update: false)
      attrs = Translation::SYNC_ATTRIBUTES.index_with { |attr| trans.public_send(attr) }
      if !to_update
        attrs.merge!( {update_user_id: trans.update_user_id,
                       updated_at:     trans.updated_at } )
      end
      attrs.merge( {sync_parent: trans} )
    end
    private :_hash_for_synchronization

  # Finds and returns the child Translation (likely) corresponding to the given Translation (of Artist)
  #
  # If everything is perfect, +translation.sync_child+ for the given Translation
  # would return it.  However, this method works on the basis of potentially
  # a far more chaotic situation; for example,
  #
  # 1. even if one of self's Translations has {#sync_translation_id}, that may not
  #    reference the Artist which the given Translation +belongs_to+.
  # 2. {#sync_translation_id} may be nil, but you must find a Translation whose
  #    contents are close, if there is any, as they would pose a risk of causing
  #    a unique-constraint violation during subsequent in-memory operations.
  # 3. if the given Translation exists only in-memory
  #    in the Artist, the DB-type referencing does not work.
  #
  # @param art_tran [Translation] of (the parent) Artist
  # @param excludes: [#include?] Usually Set or Array or Translation, the members of which are not considered as a candidate
  # @param strict: [Boolean] if false (Def: true), also performs matching based on columns (for finding a similar one to avoid unique-column violations)
  # @return [Translation, NilClass]
  def find_child_translation_of(art_tran, excludes: [], strict: false)
      current_translations = active_translations
      if new_record? && translations.blank?
        cur_translations = unsaved_translations
      end

      # Tier 1: Match by explicit lineage (In-memory reference OR DB foreign key)
      child = current_translations.find { |c|
        !excludes.include?(c) &&
          ((c.sync_parent.present? && c.sync_parent == art_tran) ||  # IF art_tran was ever in-memory (just for future-proof!), this would be the only way as c.sync_translation_id is always nil.
           (c.sync_translation_id.present? && c.sync_translation_id == art_tran.id))  # to avoid multiple DB calls
      }
      return child if strict || child

      # Tier 2: Match by composite key
      #   This step is necessary because otherwise a race condition may
      #   result in a unique-constraint violation where you destroy one and
      #   create an almost identical one in one transaction, e.g.,
      #   if you associate a Translation, decouple it, and re-associate it.
      child ||= current_translations.find { |c|
        !excludes.include?(c) &&
          Translation::TRANSLATION_UNIQUE_COLUMNS_PER_PARENT.all? { |col|
            c.public_send(col) == art_tran.public_send(col)
          }
      }
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

  # Decouples from Artist's translations.
  #
  # @return [void]
  def nullify_sync_translations
    translations.each do |trans|
      trans.sync_translation_id = nil
    end
  end

  ###################

  # Custom validation
  #
  # No {Translation#sync_translation_id} if no Artist (and themselves==false)
  def no_artist_no_sync
    if active_translations.map(&:sync_parent).compact.present?
      errors.add :themselves, "Translation#sync_translation_id should be nil when themselves==false."
    end
  end
  private :no_artist_no_sync

  # Custom validation
  #
  # No two ChannelOwner-s with themselves==true can have a common parent Artist
  def sole_themselves_per_artist?
    if themselves && artist && self.class.where(artist_id: artist.id, themselves: true).where.not(id: id).exists?
      errors.add :themselves, "cannot have themselves==true with this Artist because another ChannelOwner is alreay defined for them."
    end
  end
  private :sole_themselves_per_artist?

  # Custom validation (called when artist.present?, themselves==true)
  #
  def orig_locale_must_match_artist
    return true if skip_orig_locale_validation
    if orig_locale != (exp=artist.orig_locale)
      errors.add(:orig_locale, "must match the parent artist's orig_locale #{exp.inspect} when themselves is true")
    end
  end
  private :orig_locale_must_match_artist

  # Custom validation (called when artist.present?, themselves==true)
  #
  # {Translation#sync_translation_id} must be set for all the children Translation
  def presence_of_sync_parent
    errmsgs = active_translations.map{ |etra|
      etra.sync_parent.blank? ? sprintf("%s [%s]", (etra.id || "NEW"), etra.langcode) : nil
    }.compact
    if errmsgs.present?
      errors.add(:base, "sync_translation_id in associated Translations is missing in "+errmsgs.inspect)
    end
  end
  private :presence_of_sync_parent

  # Custom validation (called when artist.present?, themselves==true)
  #
  # {Translation#sync_translation_id} must be set for all the children Translation
  def synced_all_translations
    cho_tras = active_translations
    art_tras = artist.translations.load

    if (nall=cho_tras.size) != (nsync=cho_tras.map(&:sync_parent).compact.size)
      errors.add(:base, ":sync_translation_id are missing in #{nall-nsync} out of #{nall} Translations")  # NOTE: this checks not only the total number but also its one-to-one correspondence.
      return
    elsif art_tras.select(&:persisted?).map(&:id).sort != cho_tras.map(&:sync_parent).compact.map(&:id).sort
      errors.add(:base, "associated #{cho_tras.size} Translations do not match with #{art_tras.size} Translations of parent Artist")  # NOTE: this checks not only the total number but also its one-to-one correspondence.
      return
    end

    errmsgs = []
    cho_tras.each_with_index do |etra, i_tra|
      tra_parent = etra.sync_parent
      Translation::SYNC_ATTRIBUTES.each do |eatt|
        if tra_parent.send(eatt).presence != etra.send(eatt).presence
          errmsgs.push sprintf("(ID=%s):%s[%s]", [etra.id, tra_parent.id].inspect, eatt.t_s, etra.langcode.to_s)
        end
      end
    end

    if errmsgs.present?
      errors.add(:base, "Translation column values differ between ChannelOwner and Artist"+errmsgs.inspect)
    end
  end
  private :synced_all_translations

  # Custom validation
  #
  # If themselves==true, a valid (unsaved_)translations, which are basically
  # identical to those of the parent Artist for all the languages, must be supplied.
  #
  # If this fails, you may run {#synchronize_translations_to_artist}
  def presence_of_valid_translations
    return if !artist  # separately validated.
    msg_trans = (new_record? ? "in-memory-" : "")+"translations"
    artrans = active_translations
    if new_record? && translations.blank?
      artrans = unsaved_translations
      msg_trans = "unsaved_translations"
    end

    artist_valid_translations = artist.active_translations.select(&:persisted?)
    artist_valid_translations.each do |art_tra|
      child_tra = find_child_translation_of(art_tra, strict: true)
      if !child_tra
        content = Translation::TRANSLATION_UNIQUE_COLUMNS_PER_PARENT.index_with { |att| art_tra.public_send(att) }.inspect
        errors.add :base, "does not have #{content} in #{msg_trans} synced from parent Artist's counterpart (pID=#{art_tra.id})"
        return
      end

      # if !Translation.identical_contents?(child_tra, art_tra)  # => Boolean with no error information.
      if (hsdiff=Translation.find_unequal_content(child_tra, art_tra)).present?
        errors.add :base, "has different #{msg_trans} from the parent Artist's counterpart for language #{art_tra.langcode.inspect}: #{hsdiff.symbolize_keys.inspect}"
        return
      end
    end

    if artist_valid_translations.size != artrans.size
      errors.add :base, "has #{msg_trans} that are not present in parent Artist's children"
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

    active_translations.each do |trans|
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
    # return [] if trans.marked_for_destruction?  # NOTE: those marked_for_destruction? should not be passed here.
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
    #  (1) the parent Artist has the corresponding Translation,
    #  (2) yet self does not have one, and
    #  (3) all the main columns are identical to the parent Artist's Translation.

    lcode = trans.langcode.to_s

    hs2search = {langcode: trans.langcode.presence}
    [:title, :alt_title].each do |ek|
      val = trans.send(ek)
      hs2search[ek] = val if val.present?
    end

    art_trans = artist.translations.find_by(**hs2search)

    if !art_trans
      arret << "cannot be added as the parent Artist does not have a Translation for #{hs2search.inspect}"
      return arret
    end

    hs = Translation.find_unequal_content(trans, art_trans)
    if hs.present?
      hs.each_pair do |ek, two_values|
        arret << "has different values for #{ek} for this and parent Artist's Translation: #{two_values[0].inspect} <=> #{two_values[1].inspect}."
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
    base = self.class.joins(:translations).where(themselves: themselves, artist_id: artist_id).where.not("translations.id" => trans.id)
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
  alias_method :create_basic_bwt!,    :create_basic!    if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt)

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
    record.reset_by_artist(force: true)  # ignores inconsistent themselves when artist(_id) is specified.
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

