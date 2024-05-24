# coding: utf-8
# == Schema Information
#
# Table name: harami_vids
#
#  id                                                                                     :bigint           not null, primary key
#  duration(Total duration in seconds)                                                    :float
#  flag_by_harami(True if published/owned by Harami)                                      :boolean
#  note                                                                                   :text
#  release_date(Published date of the video)                                              :date
#  uri((YouTube) URI of the video)                                                        :text
#  uri_playlist_en(URI option part for the YouTube comment of the music list in English)  :string
#  uri_playlist_ja(URI option part for the YouTube comment of the music list in Japanese) :string
#  created_at                                                                             :datetime         not null
#  updated_at                                                                             :datetime         not null
#  channel_id                                                                             :bigint
#  place_id(The main place where the video was set in)                                    :bigint
#
# Indexes
#
#  index_harami_vids_on_channel_id    (channel_id)
#  index_harami_vids_on_place_id      (place_id)
#  index_harami_vids_on_release_date  (release_date)
#  index_harami_vids_on_uri           (uri) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (channel_id => channels.id)
#  fk_rails_...  (place_id => places.id)
#
class HaramiVid < BaseWithTranslation
  include Rails.application.routes.url_helpers
  include ApplicationHelper # for link_to_youtube
  include ModuleCommon # for convert_str_to_number_nil etc

  before_validation :add_def_channel
  before_validation :normalize_uri

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = %i(uri)

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = false  # because title is a sentence.

  # If the place column is nil, insert {Place.unknown}
  # where the callback is defined in the parent class.
  # Note there is no DB restriction, but the Rails valiation prohibits nil.
  # Therefore this method has to be called before each validation.
  before_validation :add_default_place

#################################
#  after_create :save_unsaved_associates  # callback to create(-only) @unsaved_channel,  @unsaved_artist, @unsaved_music

  belongs_to :place     # see: before_validation and "validates :place, presence: true"
  belongs_to :channel   # see: before_validation :add_def_channel
  has_many :harami_vid_music_assocs, dependent: :destroy
  has_many :harami_vid_event_item_assocs,  dependent: :destroy
  has_many :musics, -> { order(Arel.sql('CASE WHEN timing IS NULL THEN 1 ELSE 0 END, timing')) }, through: :harami_vid_music_assocs   # in the order of timing in HaramiVidMusicAssoc, which is already joined.

  has_many :event_items, through: :harami_vid_event_item_assocs  # if the unique constraint is on for Association, `distinct` is not necessary for two-component associations (but it is for multi-components)
  has_many :events,       through: :event_items
  has_many :event_groups, through: :events
  has_many :artist_music_plays, through: :event_items, source: :artist_music_plays  # to an Association model! (NOT to Artists/Musics)
  has_many :artist_collabs, -> {distinct}, through: :event_items, source: :artists
  has_many :music_plays, -> {distinct}, through: :event_items, source: :musics

  has_many :artists,     through: :musics  # duplication is possible. "distinct" would not work with ordering! So, use uniq if required.
  has_many :harami1129s, dependent: :nullify
  delegate :country,    to: :place, allow_nil: true
  delegate :prefecture, to: :place, allow_nil: true
  delegate :channel_owner,    to: :channel, allow_nil: true
  delegate :channel_type,     to: :channel, allow_nil: true
  delegate :channel_platform, to: :channel, allow_nil: true

  validates_uniqueness_of :uri, allow_nil: true  # allow_blank: false (??)
  validates :uri,   presence: true
  validates :place, presence: true  # NOT DB constraint, but Rails before_validation sets this with a default unknown Place.
  #validates :channel, presence: true  # before_validation  is taking care of. NOT DB constraint, but belongs_to constrains.
  validates_numericality_of :duration,     allow_blank: true, greater_than_or_equal_to: 0, message: "(%{value}) must be positive or 0."
  validates_numericality_of :music_timing, allow_blank: true, greater_than_or_equal_to: 0, message: "(%{value}) must be positive or 0."
  validates_numericality_of :music_year,       allow_blank: true, greater_than: 0, message: "(%{value}) must be positive."
  validates_numericality_of :form_engage_year, allow_blank: true, greater_than: 0, message: "(%{value}) must be positive."
  validates_numericality_of :form_engage_contribution, allow_blank: true, greater_than: 0, message: "(%{value}) must be positive."

  attr_accessor :unsaved_channel
  attr_accessor :unsaved_artist
  attr_accessor :unsaved_music
  attr_accessor :unsaved_event_item

  attr_accessor :form_new_event
  attr_accessor :form_channel_owner
  attr_accessor :form_channel_type
  attr_accessor :form_channel_platform
  attr_accessor :artist_name
  attr_accessor :artist_sex
  attr_accessor :form_engage_hows
  attr_accessor :form_engage_year
  attr_accessor :form_engage_contribution
  attr_accessor :artist_name_collab
  attr_accessor :form_instrument
  attr_accessor :form_play_role
  attr_accessor :music_name
  attr_accessor :music_timing  # n.b., there is a method "timing"
  attr_accessor :music_genre
  attr_accessor :music_year
  attr_accessor :form_new_artist_collab_event_item
  attr_accessor :reference_harami_vid_id

  attr_accessor :form_info  # various information about the result of form inputs, especially in create.

  DEF_PLACE = (
    (Place.unknown(country: Country['JPN']) rescue nil) ||
    Place.unknown ||
    Place.first ||
    if Rails.env == 'test'
      nil  # In the test environment, a constant should not be assigned to a model.
    else
      raise('No Place is defined, hence HaramiVid fails to be created/updated.: '+Place.all.inspect)
    end
  )

  # Hash with keys of Symbols of the columns to each String
  # value like 'youtu.be/yfasl23v'
  # The keys are [:be4, :aft][:ins_title, :ins_release_date, :ins_link_root, :ins_link_time, :event_item]
  #
  # Basically, [:be4] means the status of HaramiVid (NOT Harami1129) of the corresponding key
  # to Harami1129 before the execution.
  # For :event_item, the value is +HaramiVid.event_items.ids+ (Array!)
  attr_accessor :columns_for_harami1129

  # Returns {HaramiVidMusicAssoc#timing} of a {Music} in {HaramiVid}, assuming there is only one timing
  #
  # @param music [Music]
  # @return [Integer, NilClass]
  def timing(music)
    assocs = harami_vid_music_assocs.where(music: music).order(Arel.sql('CASE WHEN timing IS NULL THEN 1 ELSE 0 END, timing'))
    case (n=assocs.count)
    when 0
      return nil
    when 1
      # OK
    else
      # Records it in the log file.
      msg = sprintf "HaramiVid(ID=%d) has multiple (%d) timings for Music (ID=%d).", self.id, n, music.id
      logger.warn msg
    end
    # Guaranteed to be the first one
    assocs.first.timing
  end

  # Returns an existing or new record that matches a Harami1129 record
  #
  # If "uri" perfectly agrees, that is the definite identification.
  #
  # nil is returned if {Harami1129#ins_link_root} is blank.
  #
  # @param harami1129 [Harami1129]
  # @return [Harami1129, NilClass] {Translation} is associated via either {#translations} or {#unsaved_translations}
  def self.find_one_for_harami1129(harami1129)
    return nil if harami1129.ins_link_root.blank? #&& !harami1129.event_item  # if ins_link_root is nil, internal_insert has not been done, yet.
    uri = ApplicationHelper.uri_youtube(harami1129.ins_link_root)
    cands = self.where(uri: uri)
    n_cands = cands.count
    if n_cands > 0
      if n_cands != 1
        msg = sprintf "multiple (n=%d) HaramiVids found (corresponding to Harami1129(ID=%d)) of uri= %s / Returned-ID: %d", n_cands , harami1129.id, uri, cands.first.id
        log.warn msg
      end
      return cands.first
    end

    return self.new if !harami1129.event_item

    cands = HaramiVid.joins(harami_vid_event_item_assocs: :event_item).joins(harami1129s: :event_item).where("harami1129s.id" => harami1129.id)
    if (n_cands=cands.count) != 1
      msg = sprintf "multiple (n=%d) HaramiVids found (corresponding to Harami1129(ID=%d)) of uri= %s and Harami1129.event_item(id=%d) / Returned-ID: %d", n_cands , harami1129.id, uri, harami1129.event_item_id, cands.first.id
      log.warn msg
    end
    cands.first
  end

  # self.errors are set, copied from {ArtistMusicPlay#errors}, if anything has gone wrong.
  #
  # Usually, HaramiVid should have at least 1 {EventItem} — that is the constraint
  # for any newly created HaramiVid and those that is associated with an EventItem;
  # i.e., {HaramiVid#event_items} is not allowed to be empty.
  #
  # However, a legacy Hramivid may have no {EventItem} associated. HaramiVidsController
  # and Views force the user via UI to specify 1 new EventItem. So, such a legacy
  # HaramiVid should have at least 1 EventItem by the time they call this method.
  #
  # An exception is when a GET paraeter +ref_harami_vid+ (instance variable +@ref_harami_vid+
  # is given to HaramiVidsController on either create or update.  In such a case,
  # a HaramiVid is not unlikely to have multiple HaramiVids, but then, one (or more) of
  # the EventItem-s should be associated with Music and default Artist already.
  # If none of them is associated to a Music that HaramiVid is associated, then
  # there is an uncertainly problem of which EventItem should be used to associate
  # to the Music.
  #
  # In such a case, this method raises a warning and skips the processing.
  # The reason is this. If all these EventItems are associted to some other HaramiVids 
  # and if not all of the HaramiVids have the Music of interest, then
  # adding an association to Music and the EventItem would contradict
  # the fact the other HaramiVid(s) doss not have the Music(!).  Note that
  # a HaramiVid having a Music (via HaramiVidMusicAssoc) but not an ArtistMusicPlay
  # for the Music is fine because the latter means some one actually plays a Music
  # (in the HaramiVid) whereas the former simply means Music is somehow related to the HaramiVid;
  # however, the other way around is undesirable.
  #
  # So, a practical strategy is to specify +ref_harami_vid+ only when the existing
  # one is the superset of the current one, such as, the existing one being
  # the full video and the current one being a short like TikTok.
  # Also, it is best not specify a new Music when +ref_harami_vid+ is given
  # (maybe constrined via UI?).
  #
  # In practice, such a situation (of multiple candidates) may occur via UI when
  #
  # 1. a user specifies +ref_harami_vid+, referring to an existing HaramiVid none of
  #    the associated EventItems of which have Musics of the current HaramiVid because
  #    1. the existing HaramiVid is either a subset of the current HaramiVids
  #       (hence having fewer EventItems than those the current one should have),
  #       or simpley unrelated (either by mistake or by intention, such as, the user
  #       intends to amend the set of EventItems later).
  # 2. a user specifies a new Music, yet reusing old EventItem-s?
  #
  # @param form_attr [Symbol] usually the form's name
  # @return [Arrray<ArtistMusicPlay>] If everything goes well, the same thing can be accessed by {#artist_music_plays}. However, if (one of) save fails, this Array (also) contains the ArtistMusicPlay for which saving failed.
  def associate_harami_existing_musics_plays(event_item=nil, instrument: nil, play_role: nil, music_except: nil, form_attr: :base)
    if event_item
      evit_ids = event_item.id  # Integer (but OK as far as +where+ clauses are concerned)
    else
      evit_ids = event_item_ids # Array of Integers
      if !event_item && evit_ids.empty?
        raise "ERROR:(HaramiVid##{__method__}) No EventItem is specified or found."
      end
    end

    arret = []
    musics.each do |music|
      next if music_except == music
      arret << amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item: event_item, event_item_ids: evit_ids, music: music, instrument: instrument, play_role: play_role)  # new for the default ArtistMusicPlay (event_item and music are mandatory to specify.
      next if !amp.new_record?

      if !event_item
        msg = "Multiple EventItem-s are specified to associate to HaraiVid's Music (#{music.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true).inspect}). Playing association is not created. You may manually add it later."
        flash[:warning] ||= []
        flash[:warning] << "Warning: "+msg
        msg = "WARNING:(HaramiVid##{__method__}) "+msg+" EventItem(pID=#{event_item.id}: #{event_item.title.inspect})"
        warn msg
        logger.warning msg
        next
      end

      next if amp.save  # may or may not succeed.

      # This should not fail, but just in case...
      amp.errors.full_messages.each do |msg|
        errors.add form_attr, ": Existing ArtistMusicPlay is not found, yet failed to create a new one for EventItem (pID=#{event_item.id}: #{event_item.title.inspect}) and Music (pID=#{music.id}: #{music.title.inspect}): "+msg
      end
    end
    artist_music_plays.reset
    arret
  end

  # Sets the data from {Harami1129}
  #
  # self is modified but NOT saved, yet.
  #
  # Note this record HaramiVid is one record per video. Therefore,
  # {Harami1129#link_time} will not be referred to and will be recorded in HaramiVidMusicAssoc.
  #
  # The returned model instance may be filled with, if existing, all updated information
  # as specified in updates. If updates do not contain the column
  # (e.g., :ins_title), nothing is done. An existing column is not
  # updated in default (regardless of updates) unless force option is specified.
  #
  # As for {EventItem}, if HaramiVid has no child EventItem and if Harami1129 belongs to one,
  # HaramiVid's one is updated (a new {HaramiVidEventItemAssoc} is creasted).  Otherwise no change.
  #
  # @param harami1129 [Harami1129]
  # @param updates: [Array<Symbol>] Updated columns in Symbol; n.b., :uri is redundant b/c it is always read regardless.
  # @param force: [Boolean] if true, all the record values are forcibly updated (Def: false).
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {HaramiVid#columns_for_harami1129} for the returned value is set.
  # @return [Harami1129] {Translation} is associated via either {#translations} or {#unsaved_translations}
  #   Note the caller has no need to receive the return as the contents of self is modified anyway, though not saved, yet.
  # @raise [MultiTranslationError::InsufficientInformationError] if a new record cannot be created.
  def set_with_harami1129(harami1129, updates: [], force: false, dryrun: false)
    self.columns_for_harami1129 = {:be4 => {}, :aft => {}}
    if updates.include?(:ins_link_root)
      uri2set = (harami1129.ins_link_root ? ApplicationHelper.uri_youtube(harami1129.ins_link_root) : nil)
      self.columns_for_harami1129[:be4][:ins_link_root] = uri
      self.uri = uri2set if uri.blank? || force
      self.columns_for_harami1129[:aft][:ins_link_root] = uri
    elsif self.new_record?
      msg = "(#{__method__}) HaramiVid is a new record, yet :ins_link_root is not specified (link_root=#{harami1129.link_root.inspect}, updates=#{updates.inspect}). Contact the code developer."
      raise MultiTranslationError::InsufficientInformationError, msg
    end

    self.columns_for_harami1129[:be4][:ins_release_date] = release_date
    self.release_date = harami1129.ins_release_date if updates.include?(:ins_release_date) && (force || release_date.nil?)
    self.columns_for_harami1129[:aft][:ins_release_date] = release_date

#
#    ## EventItem (an Array of IDs is set to columns_for_harami1129; never nil but can be empty?)
#    self.columns_for_harami1129[:be4][:event_item] = (ar_id=event_items.ids)
#    self.columns_for_harami1129[:aft][:event_item] =
#      if harami1129.event_item && ar_id.empty?
#        event_items << harami1129.event_item if !dryrun || self.new_record?
#        [harami1129.event_item.id]
#      else
#        columns_for_harami1129[:be4][:event_item]
#      end
#
#    ## A {Place} may be assigned here
#    # self.place = Place['JPN'] if !place  # NOTE: Place['JPN'] used to be assigned unconditionally!
#    if !place && !columns_for_harami1129[:aft][:event_item].empty?  # the latter is equivalent to self.event_items.ids
#      # NOTE: self.reload or self.event_items cannot be used here because self may be a new_record?
#      self.place = EventItem.where(id: columns_for_harami1129[:aft][:event_item]).first.place
#    end
#    # NOTE: EventItem should be always defined in Harami1129 (after its internal_insert).
#    #   Therefore, no default Place is defined here. However, in practice, the default place
#    #   for EventItem defined from Harami1129 is still Japan, taken from config.
#    #   See Harami1129#set_event_item_ref which calls /app/models/concerns/module_guess_place.rb
#    #   which refers to config in Default.

    ## Translations

    self.columns_for_harami1129[:be4][:ins_title] = nil if self.new_record?
    return self if !updates.include?(:ins_title)

    all_trans = translations

    # If one or more Translation exists, whether it agrees or not, 
    # no Translation is added (let alone updated) unless force option is specified.
    return self if all_trans.size > 0 && !force && !dryrun

    # Even if force==true, if a matched Translation is found,
    # no new Translation is created (the validation would fail).
    all_trans.each do |ea_tra|
      if ea_tra.titles.include? harami1129.ins_title
        # Perfect match is the condition so far.  Can be improved.
        # Note langcode does not matter.
        #
        # Perfect match means this would be the identical value
        # to the one if the current ins_title was populated.
        self.matched_translation = ea_tra
        att = ((ea_tra.title == harami1129.ins_title) ? :title : :alt_title)
        ea_tra.matched_attribute = att
        self.matched_attribute   = att
        self.columns_for_harami1129[:be4][:ins_title] = matched_string
        self.columns_for_harami1129[:aft][:ins_title] = self.columns_for_harami1129[:be4][:ins_title].dup
        return self
      end
      #return self if ea_tra.titles.include? harami1129.ins_title
    end

    if all_trans.size > 0 && dryrun
      # A corresponding HaramiVid exists but the translation does not agree.
      best_tra = best_translations
      ea_tra = (best_tra['ja'] || best_tra['en'] || all_trans.first)
      self.matched_translation = ea_tra
      ea_tra.matched_attribute = :title
      self.matched_attribute   = :title
      self.columns_for_harami1129[:be4][:ins_title] = matched_string
      self.columns_for_harami1129[:aft][:ins_title] = self.columns_for_harami1129[:be4][:ins_title].dup
      return self
    end

    # Now, the situation is
    # either no corresponding Harami1129 is found OR
    # (the existing HaramiVid disagrees in the title with Harami1129#ins_title
    #  AND force=true).
    # Therefore,
    # a new Translation is now created, which will be saved when the instance is saved.
    trans = Translation.preprocessed_new(title: harami1129.ins_title, is_orig: true, translatable_type: self.class.name)
    trans.langcode = guess_lang_code(trans.title)
    #if unsaved_translations
    #  self.unsaved_translations.push trans
    #else
    #  self.unsaved_translations = [trans]
    #end
    self.unsaved_translations << trans
    self.unsaved_translations[-1].matched_attribute = :title
    self.matched_translation = trans
    self.matched_attribute   = :title
    self.columns_for_harami1129[:be4][:ins_title] ||= nil
    self.columns_for_harami1129[:aft][:ins_title] = harami1129.ins_title

    self
  end

  # Set EventItem association
  #
  # Also this may update {HaramiVid#place}. If not, self (=HaramiVid) is not updated.
  # Just an association HaramiVidEventItemAssoc and ArtistMusicPlay (HARAMIchan playing) may be created.
  #
  # @param harami1129 [Harami1129]
  # @param force: [Boolean] if true, all the record values are forcibly updated (Def: false).
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {HaramiVid#columns_for_harami1129} for the returned value is set.
  # @return [Harami1129] {Translation} is associated via either {#translations} or {#unsaved_translations}
  #   Note the caller has no need to receive the return as the contents of self is modified anyway, whether it is saved or not.
  def set_with_harami1129_event_item_assoc(harami1129, force: false, dryrun: false)
    self.columns_for_harami1129 ||= {:be4 => {}, :aft => {}}

    ## EventItem (an Array of IDs is set to columns_for_harami1129; never nil but can be empty?)
    self.columns_for_harami1129[:be4][:event_item] = (ar_id=event_items.ids)
    self.columns_for_harami1129[:aft][:event_item] =
      if harami1129.event_item && ar_id.empty?
        event_items << harami1129.event_item if !dryrun || self.new_record?  # HaramiVidEventItemAssoc is immediately created unless self is a new record
        [harami1129.event_item.id]
      else
        columns_for_harami1129[:be4][:event_item]
      end

    ## A {Place} may be assigned here
    # self.place = Place['JPN'] if !place  # NOTE: Place['JPN'] used to be assigned unconditionally!
    if (!place || force) && !columns_for_harami1129[:aft][:event_item].empty?  # the latter is equivalent to self.event_items.ids
      # NOTE: self.reload or self.event_items cannot be used here because self may be a new_record?
      self.place = EventItem.where(id: columns_for_harami1129[:aft][:event_item]).first.place
      save! if force || !dryrun
    end
    # NOTE: EventItem should be always defined in Harami1129 (after its internal_insert).
    #   Therefore, no default Place is defined here. However, in practice, the default place
    #   for EventItem defined from Harami1129 is still Japan, taken from config.
    #   See Harami1129#set_event_item_ref which calls /app/models/concerns/module_guess_place.rb
    #   which refers to config in Default.

    self
  end

  # Returns "music<br>music<br>..." for Home#index View
  #
  # @param langcode [String]
  # @return [String]
  def view_home_music(langcode)
    musics.map{|ea_mu|
      timing = timing(ea_mu)
      tit = ea_mu.title(langcode: langcode.to_s, lang_fallback: false, str_fallback: nil)
      if !tit && 'en' == langcode.to_s
        tit = ea_mu.romaji(langcode: 'ja')  # English fallback => Romaji in JA
        tit &&= '['+tit+']'
      end
      link_str = (tit.blank? ? '&mdash;' : ActionController::Base.helpers.link_to(tit, music_path(ea_mu)))
      hms_or_ms = sec2hms_or_ms(timing)
      ylink_en = link_to_youtube(hms_or_ms, uri, timing)  # defined in application_helper.rb
#ylink_en = link_to_youtube sprintf('%d'+I18n.t('s_time')+'—', (timing || 0)), uri, timing  # defined in application_helper.rb
      sprintf "%s (%s)", link_str, ylink_en
    }.join('<br>').html_safe
  end


  # Returns "artist1 + ……<br>artist2<br>..." for Home#index View
  #
  # where artist1 and artist2 are the links for {Artist},
  # whereas '……' is the link for {Music}
  #
  # @param langcode [String]
  # @return [String]
  def view_home_artist(langcode='en')
    musics.map{|ea_mu|
      arts = ea_mu.sorted_artists.uniq
      n_arts = arts.count
      art1st = arts[0]
      next '&mdash;'.html_safe if 0 == n_arts || art1st.unknown?
      tit = (art1st.title(langcode: langcode) || art1st.title)
      s1 = ActionController::Base.helpers.link_to(tit, artist_path(art1st))
      next s1 if 1 == n_arts
      s1+', '+ActionController::Base.helpers.link_to('……', music_path(ea_mu))
    }.join('<br>').html_safe
  end

  # @return [HaramiVid::ActiveRecord_Relation] Other HaramiVids that share the same EventItem-s
  def other_harami_vids_of_event_items
    hv_ids = event_items.ids
    HaramiVid.joins(:event_items).where("event_items.id" => hv_ids).where.not("harami_vids.id" => id).distinct
  end

  ########## Before-validation callbacks ##########

  # Callback before_validation
  #
  # This should not be invoked - Controllers should take care of.
  def add_def_channel
    self.channel ||= Channel.primary
  end

  # Callback before_validation
  #
  # saving uri in DB like
  #   "youtu.be/WFfas92FA?t=24"
  # as opposed to
  #   "youtu.be.com/shorts/WFfas92FA?t=24"
  #   "https://www.youtube.com/watch?v=WFfas92FA?t=24s&link=youtu.be"
  #   "https://www.youtube.com/live/vXABC6EvPXc?si=OOMorKVoVqoh-S5h?t=24"
  #
  # In fact, time-query-parameter is not recommended...
  def normalize_uri
    self.uri = ApplicationHelper.normalized_uri_youtube(uri, long: false, with_scheme: false, with_host: true,  with_time: true) if uri.present?
  end
 

  private    ################### Callbacks

    def add_default_place
      self.place = (DEF_PLACE || Place.first) if !self.place
    end

    # Channel is automatically associated with Translations after_create
    def save_unsaved_associates  # callback to create(-only) 
      are_new = {
        channel: false,
        event_item: false, 
        artist: false,
        music: false,
      }
      @unsaved_channel && are_new[:channel]=true && @unsaved_channel.save!
      @unsaved_event_item && are_new[:event_item]=true && @unsaved_event_item.save!
      @unsaved_artist  && are_new[:artist]=true  && @unsaved_artist.save!
      @unsaved_music   && are_new[:music]=true   && @unsaved_music.save!

      if are_new[:music]
        save_harami_vid_music_assoc
      end
      if are_new[:artist] || are_new[:music]
        save_engage
      end
      if are_new[:artist] || are_new[:music] || are_new[:event_item]
        save_artist_music_play
      end
    end

    # Channel is automatically associated with Translations after_create
    def save_harami_vid_music_assoc  # method called from callback to create(-only) 
      return if !@unsaved_music
      if @unsaved_musici.new_record?
        errors.add :base, "Music cannot be handled for an unknown reason... Contact the code developer."  # desirable to define this in case the Exception is caught somewhere upstream in the future.
        msg = "ERROR(#{File.basename __FILE__}:#{__method__}): @unsaved_music is strange: #{@unsaved_music.inspect}" 
        logger.error msg
        raise msg
      end

      hvma = HaramiVidMusicAssoc.find_or_initialize_by(harami_vid: self, music: @unsaved_music)
      hvma.timing = music_timing.to_i if music_timing.present?  # it has been validated to be numeric if present.
      if result = hvma.save
        msg = "Something goes wrong in saving Music-Video association"
        errors.add :music_name, msg
        logger.error msg
        raise msg
      end
    end

    # Channel is automatically associated with Translations after_create
    def save_engage  # method called from callback to create(-only) 
      eng = engage.find_or_initialize_by(music: @unsaved_music, artist: @unsaved_artist)
      eng.timing = music_timing.to_i if music_timing.present?
      eng.save!
    end

end


class << HaramiVid
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, uri: nil, **kwds, &blok)
    uri ||= "https://example.com/"+(0...8).map{(65 + rand(26)).chr}.join
    create_basic_bwt!(*args, uri: uri, **kwds, &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  # Unlike {#create_basic!}, an existing Sex is used, which is assumed to exist.
  def initialize_basic(*args, uri: nil, **kwds, &blok)
    uri ||= "https://example.com/"+(0...8).map{(65 + rand(26)).chr}.join
    initialize_basic_bwt(*args, uri: uri, **kwds, &blok)
  end
end


