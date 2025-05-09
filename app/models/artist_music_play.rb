# == Schema Information
#
# Table name: artist_music_plays
#
#  id                                                       :bigint           not null, primary key
#  contribution_artist(Contribution of the Artist to Music) :float
#  cover_ratio(How much ratio of Music is played)           :float
#  note                                                     :text
#  created_at                                               :datetime         not null
#  updated_at                                               :datetime         not null
#  artist_id                                                :bigint           not null
#  event_item_id                                            :bigint           not null
#  instrument_id                                            :bigint           not null
#  music_id                                                 :bigint           not null
#  play_role_id                                             :bigint           not null
#
# Indexes
#
#  index_artist_music_plays_5unique           (event_item_id,artist_id,music_id,play_role_id,instrument_id) UNIQUE
#  index_artist_music_plays_on_artist_id      (artist_id)
#  index_artist_music_plays_on_event_item_id  (event_item_id)
#  index_artist_music_plays_on_instrument_id  (instrument_id)
#  index_artist_music_plays_on_music_id       (music_id)
#  index_artist_music_plays_on_play_role_id   (play_role_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id) ON DELETE => cascade
#  fk_rails_...  (event_item_id => event_items.id) ON DELETE => cascade
#  fk_rails_...  (instrument_id => instruments.id) ON DELETE => cascade
#  fk_rails_...  (music_id => musics.id) ON DELETE => cascade
#  fk_rails_...  (play_role_id => play_roles.id) ON DELETE => cascade
#
class ArtistMusicPlay < ApplicationRecord
  belongs_to :event_item
  belongs_to :artist
  belongs_to :music
  belongs_to :play_role
  belongs_to :instrument
  has_many :harami_vid_event_item_assocs, through: :event_item
  delegate :harami_vids, to: :event_item

  attr_accessor :to_destroy  # dummy accessor for simple_form

  validates :event_item, uniqueness: {scope: %i(artist music play_role instrument)}, allow_nil: false
  validates :contribution_artist, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :cover_ratio,         numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s
  include ModuleModifyInspectPrintReference
  redefine_inspect(cols_yield: %w(event_item_id)){ |record, _|
    sprintf("(%s)", record.machine_title)
  }

  # Returns {ArtistMusicPlay} with the default Artist (in the given context) for specified EventItem and Music
  #
  # If any {ArtistMusicPlay} with the default Artist for the EventItem and Music
  # (regardless of {Instruent} and {PlayRole}) defined already, returns the first one found (+new_record? == false+).
  # Otherwise an initialized {ArtistMusicPlay} with +new_record?==true+ is returned.
  #
  # @example single
  #    amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid,
  #            event_item: Event.default(:HaramiVid).unknown_event_item, music: Music.last)
  #    amp.save! if amp.new_record?
  #
  # @example multiple
  #    amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid,
  #            event_item_ids: ["123", "456"], music: Music.last)
  #    amp.save! if amp.new_record?
  #
  # Either a single EventItem or pIDs of multiple EventItems is mandatory.
  #
  # In the latter case, if an existing ArtistMusicPlay to match the condition is not found,
  # the first ID in the given Array (+event_item_ids+) is used for the EventItem to
  # initialize an ArtistMusicPlay to return.
  #
  # @param event_item: [EventItem]
  # @param event_item_ids: [Array<Integer, String>] {HaramiVid#event_item_ids} etc.  String form of an Integer is accepted.
  # @return [ArtistMusicPlay]
  def self.initialize_default_artist(context=nil, music: , event_item: nil, event_item_ids: nil, instrument: nil, play_role: nil)
    instrument ||= Instrument.default(context)
    play_role  ||= PlayRole.default(context)

    hsbase = {
      artist: Artist.default(:HaramiVid),
      music: music,
    }

    hs2find = {}
    hs4new  = {}
    if event_item
      hsbase[:event_item] = event_item
    elsif event_item_ids.present?
      hs2find[:event_item_id] = event_item_ids  # => where(event_item_id: [12, 34, 56])
      hs4new[ :event_item_id] = event_item_ids.first
    else
      raise ArgumentError, "(#{__method__}) Either a single EventItem or (non-empty) Array of pIDs of one or more EventItems is mandatory."
    end

    amp_cand = where(**(hsbase.merge(hs2find))).first
    return amp_cand if amp_cand  # new_record? == false

    new(**(hsbase.merge(hs4new).merge({instrument: instrument, play_role: play_role})))
  end

  # Returns Relation of all ArtistMusicPlay-s same as self except for keywords
  #
  # Note the form of "XXX_id" is not accepted!
  #
  # Note if multiple keys are specified, they are treated as AND; e.g., 
  #    sames_but(music: Music.first, artist: Artist.first)
  # returns those that has neither of Music and Artist, and so they include
  # ArtistMusicPlay with the Artist but not Music.
  #
  # @example
  #   amp.sames_but(event_item: EventItem.first)
  #
  # @param kwds [Hash<ActiveRecord>]
  # @return [ArtistMusicPlay::Relation]
  def sames_but(**kwds)
    hsin = {}
    hsout = {}
    %i(artist event_item instrument music play_role).each do |ek|
      k = ek.to_s+"_id"
      if kwds.has_key?(ek)
        hsout[k] = kwds[ek].id
      else
        hsin[k]  = send(ek).id
      end
    end

    self.class.where(hsin).where.not(hsout)
  end
end
