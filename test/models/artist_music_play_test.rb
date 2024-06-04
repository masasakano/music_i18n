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
require "test_helper"

class ArtistMusicPlayTest < ActiveSupport::TestCase
  test "association" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")

    amp0 = ArtistMusicPlay.create!(event_item: evi0, artist: art0, music: mus0, play_role: PlayRole.first, instrument: Instrument.first)
    assert amp0

    ampe = ArtistMusicPlay.new(event_item: evi0, artist: art0, music: mus0, play_role: PlayRole.first, instrument: Instrument.first)
    assert_raises(ActiveRecord::RecordNotUnique){ ampe.save!(validate: false) } # DB level: <"PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_artist_music_plays_5unique\"\nDETAIL:  Key (event_item_id, artist_id, music_id, play_role_id, instrument_id)=(965783327, ...) already exists.\n">
    assert_raises(ActiveRecord::RecordInvalid){   ampe.save! } 

    ampe.instrument = nil
    assert_raises(ActiveRecord::NotNullViolation){ampe.save!(validate: false) } # DB level: <"PG::NotNullViolation: ERROR:  null value in column \"instrument_id\" of relation \"artist_music_plays\" violates not-null constraint\nDETAIL:  Failing row contains (980190965, ...).\n">
    assert_raises(ActiveRecord::RecordInvalid){   ampe.save! }  # automatic because of belongs_to 

    ampe.instrument_id = Instrument.order(:id).last.id + 1
    assert_raises(ActiveRecord::InvalidForeignKey){ampe.save!(validate: false) } # DB level: <"PG::ForeignKeyViolation: ERROR:  insert or update on table \"artist_music_plays\" violates foreign key constraint \"fk_rails_841554622d\"\nDETAIL:  Key (instrument_id)=(1066896093) is not present in table \"instruments\".\n">
    assert_raises(ActiveRecord::RecordInvalid){   ampe.save! }  # automatic because of belongs_to
  end

  test "self.initialize_default_artist" do
    mu = musics(:music_light)
    organ = instruments(:instrument_organ)
    evit1 = EventItem.create_basic!(event: (ev3=events(:three)), machine_title: "evit1")
    evit2 = EventItem.create_basic!(event: (ev3=events(:three)), machine_title: "evit2")
    evit3 = EventItem.create_basic!(event: (ev3=events(:three)), machine_title: "evit3")
    amp10 = ArtistMusicPlay.initialize_default_artist(music: mu, event_item: evit1, event_item_ids: nil, instrument: organ)
    assert amp10.new_record?
    assert amp10.valid?
    amp10.save!

    amp11 = ArtistMusicPlay.initialize_default_artist(music: mu, event_item: evit1, event_item_ids: nil, instrument: organ)
    refute amp11.new_record?, "existing one should be found and returned, but...: #{amp11.inspect}"
    assert_equal amp10, amp11

    ary = [evit1, evit2, evit3].map{|i| i.id.to_s}
    amp12 = ArtistMusicPlay.initialize_default_artist(music: mu, event_item_ids: ary, instrument: organ)
    refute amp12.new_record?, "existing one should be found and returned, but...: #{amp12.inspect}"
    assert_equal amp10, amp12

    amp20 = ArtistMusicPlay.initialize_default_artist(music: mu, event_item_ids: ary[1..2], instrument: organ)
    assert amp20.new_record?, "existing one should be found and returned, but...: #{amp12.inspect}"
    assert amp20.valid?
    assert amp20.save!
    refute_equal amp10, amp20
  end
end

