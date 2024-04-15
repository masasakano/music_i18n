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

end
