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

  validates :event_item, uniqueness: {scope: %i(artist music play_role instrument)}, allow_nil: false

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s

  # Information of "(Prefecture < Country-Code)" is added.
  # @return [String]
  def inspect
    return(super) if !event_item && !artist && !music && !play_role && !instrument

    hsprm = %i(artist music play_role instrument).map{|ek|
      [ek, ((obj=send(ek)) ? sprintf("(%s)", obj.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: "")) : "")]
    }.to_h.with_indifferent_access
    hsprm[:event_item] = (event_item ? sprintf("(%s)", event_item.machine_title) : "")

    ret = super
    hsprm.each_pair do |ek, ev|
      ret = ret.sub(/, #{ek}_id: \d+/, '\0'+ev)
    end
    ret
  end

  # Returns {ArtistMusicPlay} with the default Artist (in the given context) for specified EventItem and Music
  #
  # If any {ArtistMusicPlay} with the default Artist for the EventItem and Music
  # (regardless of {Instruent} and {PlayRole}) defined already, returns the first one found (+new_record? == false+).
  # Otherwise an initialized {ArtistMusicPlay} with +new_record?==true+ is returned.
  #
  # @example
  #    amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid,
  #            event_item: Event.default(:HaramiVid).unknown_event_item, music: Music.last)
  #    amp.save! if amp.new_record?
  #
  # @return [ArtistMusicPlay]
  def self.initialize_default_artist(context=nil, event_item: , music: , instrument: nil, play_role: nil)
    instrument ||= Instrument.default(context)
    play_role  ||= PlayRole.default(context)

    hsbase = {
      event_item: event_item,
      artist: Artist.default(:HaramiVid),
      music: music,
    }

    amp_cand = where(**hsbase).first
    return amp_cand if amp_cand  # new_record? == false

    new(**(hsbase.merge({instrument: instrument, play_role: play_role})))
  end
end
