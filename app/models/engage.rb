# coding: utf-8
# == Schema Information
#
# Table name: engages
#
#  id            :bigint           not null, primary key
#  contribution  :float
#  note          :text
#  year          :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  artist_id     :bigint           not null
#  engage_how_id :bigint           not null
#  music_id      :bigint           not null
#
# Indexes
#
#  index_engages_on_4_combinations          (artist_id,music_id,engage_how_id,year) UNIQUE
#  index_engages_on_artist_id               (artist_id)
#  index_engages_on_engage_how_id           (engage_how_id)
#  index_engages_on_music_id                (music_id)
#  index_engages_on_music_id_and_artist_id  (music_id,artist_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id) ON DELETE => cascade
#  fk_rails_...  (engage_how_id => engage_hows.id) ON DELETE => restrict
#  fk_rails_...  (music_id => musics.id) ON DELETE => cascade
#
class Engage < ApplicationRecord
  include ModuleCommon
  extend  ModuleCommon  # for guess_lang_code etc
  before_validation :set_default_engage_how  # Not before_create.

  belongs_to :music
  belongs_to :artist
  belongs_to :engage_how
  has_many :harami1129s, dependent: :restrict_with_exception  # Please nullify Harami1129.engage_id before deleting self (in the future, dependent: :nullify (and so does the DB "ON DELETE") maybe?)

  validates_numericality_of :year, allow_nil: true, greater_than: 0, message: "(%{value}) must be positive."
  validates_uniqueness_of :artist, scope: [:music, :engage_how, :year]  # year can be nil. If there are 2 records that have identical with year=nil, Rails validation fails, whereas PostgreSQL ignores it.

  # Hash with keys of Symbols of the columns to each String
  # value like 'Beatles, The'.
  # The keys are [:be4, :aft][:ins_singer, :ins_song]
  attr_accessor :columns_for_harami1129

  # for simple_form; meant to be boolean
  attr_accessor :to_destroy

  # Returns the potentially unsaved version of "unknown"
  def self.find_or_initialize_unknown
    find_or_initialize_by(music: Music.unknown, artist: Artist.unknown)
  end

  #
  def unknown?
    artist.unknown? && music.unknown?
  end

  # Returns {Engage}s of the other {Artist}s for the same {Music}
  #
  # @return [Collection]
  def with_the_other_artists
    Engage.where(music: music).where.not(artist: artist).joins(:engage_how).order('engage_hows.weight')
  end

  # Returns an existing or newly saved {Engage} that matches a Harami1129 record
  #
  # (1) The contents of the existing {Engage} is never updated.
  # (2) If the given and specified column of either {Artist} or {Music}
  #     has a different value from the existing {Engage} record
  #     (which may be {Artist.unknown} etc), a different {Engage} from
  #     the onew currently assigned to {HaramiVid}; the returned record
  #     may or may not already exist in the DB table.
  # (3) The {Artist} or {Music} (and related {Translation} referred to
  #     in the returned {Engage} both exist in the DB, whether they are
  #     newly created or existing, when {Engage} is returned.
  #     Use transaction to wrap the routine in the caller, if the caller
  #     may want to cancel the creations.
  #
  # Note that if {Harami1129#engage} is nil for the given argument,
  # the optional argument +updates+ is ignored.
  #
  # @param harami1129 [Harami1129]
  # @param updates [Array<Symbol>] Array of Symbol<ins_*> to update.
  # @param messages: [Array<String>] (intent: out) messages to be returned
  # @param dryrun: [Boolean] If true (Def: false), nothing is saved but {Engage#different_columns_for_harami1129} for the returned value is set.
  # @return [Engage] {Translation} is associated via either {#translations} or {#unsaved_translations}
  def self.find_and_set_one_harami1129(harami1129, updates: [], messages: [], dryrun: false)
    ret = harami1129.engage # || find_or_initialize_unknown)

    # If Harami1129#engage_id is nil, all related values in columns_for_harami1129[:be4] are nil.
    # NOTE: Even if dryrun, an empty Engage is required to return
    #   in order to pass ret.columns_for_harami1129 to the parent.
    engage_exists = !!ret
    colinit = {be4: {}, aft: {}}
    colinit = colinit.map{|k1, v1|
      [k1, {ins_singer: nil, ins_song: nil}]
    }.to_h

    # Search the other rows for those with the identical song/singer
    ret ||= self.find_identical_engage_for_harami1129(harami1129, messages: [])

    artist = (ret ? ret.artist : nil)
    if ret
      artist.assign_matched_translation(harami1129.ins_singer)
    else
      artist = find_and_set_artist_for_one_harami1129(harami1129, messages: messages) if updates.include?(:ins_singer) || !ret
    end

    music = (ret ? ret.music : nil)
    if ret
      music.assign_matched_translation(harami1129.ins_song)
    else
      music = find_and_set_music_for_one_harami1129(harami1129, artist: artist, messages: messages) if updates.include?(:ins_song) || !ret
    end

    col_aft = {
      ins_singer: artist.matched_string,
      ins_song:   music.matched_string,
    }
    col_be4 = {
      ins_singer: (artist.new_record? ? nil : col_aft[:ins_singer]),
      ins_song:   (music.new_record?  ? nil : col_aft[:ins_song]),
    }
    if ret && ret.artist == artist && ret.music == music # existing Engage, unchanged
      ret.columns_for_harami1129 = colinit
      ret.columns_for_harami1129[:aft] = col_aft
      ret.columns_for_harami1129[:be4] = col_be4 if engage_exists
      # ret.different_columns_for_harami1129[:ins_singer] = [ret.artist.title, ???]
      return ret
    end

    if artist.new_record?
      artist.save! if !dryrun # should be OK? Translation is saved, too.
    end
    if music.new_record?
      music.save!  if !dryrun # should be OK? Translation is saved, too.
    end

    hs = {music: music, artist: artist}
    ret = self.find_or_initialize_by(**hs)
    if ret.new_record?
      ret.engage_how = EngageHow.order(:weight).first  # For a completely new Engage for Harami1129, highest-priority EngageHow is chosen: likely "Singer (Original)"
      ret.save! if !dryrun
      #self.find_or_create_by!(**hs)
    end

    ret.columns_for_harami1129 = colinit
    ret.columns_for_harami1129[:aft] = col_aft
    ret.columns_for_harami1129[:be4] = col_be4 if engage_exists
    ret
  end

  # Find a matching {Engage} if exists
  #
  # If the identical ins_song and/or ins_singer with a significant engage
  # exists in {Harami1129}, the same {Engage} is returned so that
  # basically the rows with a common ins_song/ins_singer have
  # a common {Engage}.
  #
  # Note that only the {Engage} of part of those rows might be
  # manually modified and so there is no guarantee.
  # This is just a best-effort-based method.
  #
  # @param harami1129 [Harami1129]
  # @return [Engage, NilClass] if nothing matching is found
  def self.find_identical_engage_for_harami1129(harami1129, messages: [])
    my_ins_song   = harami1129.ins_song
    my_ins_singer = harami1129.ins_singer
    return nil if my_ins_song.blank? && my_ins_singer.blank?
    if !harami1129.ins_song.blank? && !harami1129.ins_singer.blank?
      h1129s = Harami1129.where(ins_song: my_ins_song, ins_singer: my_ins_singer).where.not(engage_id: nil)
      return nil if !h1129s.exists?
      return h1129s.joins(engage: :engage_how).order('engage_hows.id').first.engage ################## Should be weight!!!
    end

    if !harami1129.ins_song.blank?
      h1129s = Harami1129.where(ins_song: my_ins_song).where.not(engage_id: nil)
      return nil if !h1129s.exists?
      return h1129s.joins(engage: :engage_how).order('engage_hows.id').first.engage ################## Should be weight!!!
    end

    h1129s = Harami1129.where(ins_singer: my_ins_singer).where.not(engage_id: nil)
    return nil if !h1129s.exists?
    return h1129s.joins(engage: :engage_how).order('engage_hows.id').first.engage ################## Should be weight!!!
  end

  # Returns an existing or new {Artist} that matches a Harami1129 record
  #
  # @param harami1129 [Harami1129]
  # @param messages: [Array<String>] (intent: out) messages to be returned
  # @return [Artist] maybe new_record? {Translation} is associated via {#translations} or {BaseWithTranslation#unsaved_translations}
  def self.find_and_set_artist_for_one_harami1129(harami1129, messages: [])
    singer = harami1129.ins_singer
    return Artist.unknown if singer.blank?

    methods = [:exact, :exact_ilike, :optional_article_ilike] # See Translation::MATCH_METHODS for the other options
    artist = Artist.find_by_a_title(:titles, singer, accept_match_methods: methods)
    return artist if artist

    # No existing Artist is found.
    lcode = guess_lang_code(singer)
    place = Place.unknown(country: ((lcode == 'ja') ? 'JPN' : nil))
    artist = Artist.new(sex: guess_sex(singer), place: place)
    artist.unsaved_translations << Translation.new(langcode: lcode, title: singer, is_orig: true)
    artist.unsaved_translations[-1].matched_attribute = :title
    artist.matched_translation = artist.unsaved_translations[-1]
    artist.matched_attribute   = :title
    artist
  end

  # Returns an existing or new {Music} that matches a Harami1129 record
  #
  # Using {Artist} info, too.
  #
  # @param harami1129 [Harami1129]
  # @param artist: [Artist]
  # @param messages: [Array<String>] (intent: out) messages to be returned
  # @return [Music] {Translation} is associated via {#translations}
  def self.find_and_set_music_for_one_harami1129(harami1129, artist: nil, messages: [])
    music_tit  = harami1129.ins_song
    return Music.unknown if music_tit.blank?

    opts = {match_method_upto: :optional_article_ilike} # See Translation::MATCH_METHODS for the other options
    opts.merge!(artist ? {translatable_id: artist.musics.pluck(:id).flatten.uniq} : {})
    music = Music.find_by_a_title(:titles, music_tit, **opts)
    return music if music

    # No existing Music is found.
    lcode = guess_lang_code(music_tit)

    # {Place} of the music is based on the artist's place, else music's language code.
    place = (artist ? artist.place : Place.unknown(country: ((lcode == 'ja') ? 'JPN' : nil)))
    music = Music.new(place: place, genre: Genre.default) # Genre will be J-Pop
    music.unsaved_translations << Translation.new(langcode: lcode, title: music_tit, is_orig: true)
    music.unsaved_translations[-1].matched_attribute = :title
    music.matched_translation = music.unsaved_translations[-1]
    music.matched_attribute   = :title
    music
  end

  private

    def set_default_engage_how
      logger.warn "In validating Engage, EngageHow is somehow undefined (nil), which should have been set by the frontend. Engage.unknonw is set instead." if !engage_how
      self.engage_how ||= EngageHow.unknown
      if !engage_how
        msg = 'ERROR: In creating (stritctly speaking, in validating) Engage without explicitly specifying EngageHow, UnknownEngageHow is essential but is not found for some reason.  Maybe seeds are not planted or accidentally deleted?'
        logger.error msg
        warn msg
        raise msg
      end
    end
end

