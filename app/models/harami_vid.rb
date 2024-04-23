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
  include ModuleCommon

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

  belongs_to :place
  belongs_to :channel
  has_many :harami_vid_music_assocs, dependent: :destroy
  has_many :musics, -> { order(Arel.sql('CASE WHEN timing IS NULL THEN 1 ELSE 0 END, timing')) }, through: :harami_vid_music_assocs   # in the order of timing in HaramiVidMusicAssoc, which is already joined.

  has_many :artists, through: :musics
  has_many :harami1129s, dependent: :nullify
  delegate :country,    to: :place, allow_nil: true
  delegate :prefecture, to: :place, allow_nil: true

  validates_uniqueness_of :uri, allow_nil: true
  validates :place, presence: true  # NOT DB constraint, but Rails before_validation sets this with a default unknown Place

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
  # The keys are [:be4, :aft][:ins_title, :ins_release_date, :ins_link_root, :ins_link_time]
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
    return nil if harami1129.ins_link_root.blank?
    uri = ApplicationHelper.uri_youtube(harami1129.ins_link_root)
    cands = self.where(uri: uri)
    n_cands = cands.count
    if n_cands > 0
      if n_cands != 1
        msg = sprintf "HaramiVid has multiple (n=%i) records (corresponding to Harami1129(ID=%d)) of uri= %s / Returned-ID: %d", n_cands , harami1129.id, uri, cands.first.id
        log.warn msg
      end
      harami_vid = cands.first
    else
      harami_vid = self.new
    end

    harami_vid
  end

  # Sets the data from {Harami1129}
  #
  # self is modified but NOT saved, yet.
  #
  # Note this record HaramiVid is one record per video. Therefore,
  # {Harami1129#link_time} will not be referred to.
  #
  # The returned model instance may be filled with, if existing, all updated information
  # as specified in updates. If updates do not contain the column
  # (e.g., :ins_title), nothing is done. An existing column is not
  # updated in default (regardless of updates) unless force option is specified.
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

    ## A {Place} may be assigned here
    # Future project
    self.place = Place['JPN'] if !place

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

  # Returns "music<br>music<br>..." for Home#index View
  #
  # @param langcode [String]
  # @return [String]
  def view_home_music(langcode)
    musics.map{|ea_mu|
      timing = timing(ea_mu)
      tit = ea_mu.title(langcode: langcode.to_s)
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

  private

    def add_default_place
      self.place = (DEF_PLACE || Place.first) if !self.place
    end
end
