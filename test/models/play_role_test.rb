# coding: utf-8
# == Schema Information
#
# Table name: play_roles
#
#  id                                                  :bigint           not null, primary key
#  mname(unique machine name)                          :string           not null
#  note                                                :text
#  weight(weight to sort entries in Index for Editors) :float            default(999.0), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
# Indexes
#
#  index_play_roles_on_mname   (mname) UNIQUE
#  index_play_roles_on_weight  (weight)
#
require "test_helper"

class PlayRoleTest < ActiveSupport::TestCase
  test "uniqueness" do
    mdl = play_roles( :play_role_conductor )
    user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb
    ## Model contains validates_presence_of, but for some reason (maybe because of DB default?), "allow_nil: true" works...

    mdl0 = PlayRole.first.dup
    assert_raises(ActiveRecord::RecordInvalid){ # ActiveRecord::NotNullViolation at DB level
      PlayRole.create!(mname: nil,  weight: 12345) }
    assert_raises(ActiveRecord::RecordInvalid){ # ActiveRecord::NotNullViolation at DB level
      PlayRole.create!( weight: 12345) }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo", weight: nil) }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo", weight: "abc") }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo", weight: -4) }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo") }  # This raises an Exception BECAUSE "unknown" has the weight of the DB-default 999.0

    mdl = PlayRole.new(mname: mdl0.mname, weight: 50)
    refute mdl.save
    mdl = PlayRole.new(mname: "naiyo", weight: mdl0.weight)
    refute mdl.save

    assert((puk=PlayRole.unknown).unknown?)
    assert_equal PlayRole::UNKNOWN_TITLES['en'][1], puk.alt_title(langcode: :en), "WARNING: This for some reason someitmes fails as a result of the alt_title of being nil.... PlayRole.unknown="+puk.inspect+puk.best_translations["en"].inspect

    ## checking fixtures
    tra = translations(:play_role_singer_en)
    assert_equal "Singer", tra.title
    assert_equal "en",   tra.langcode
    assert_equal "PlayRoleSingerEn", tra.note

    tra = translations(:play_role_singer_ja)
    assert_equal "ja",   tra.langcode
    assert_equal "歌手", tra.title
    assert_equal "singer", tra.translatable.mname
    assert_equal 10,       tra.translatable.weight

    tra = translations(:play_role_other_ja)
    assert_equal "その他", tra.title
  end

  test "associations via ArtistMusicPlayTest" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")
    plr0 = play_roles(:play_role_conductor)

    plr1  = play_roles(:play_role_inst_player_main)
    evit1 = event_items(:evit_1_harami_budokan2022_soiree)
    assert_operator 1, :<=, plr1.artist_music_plays.count, 'check has_many artist_music_plays and also fixtures'
    assert_operator 1, :<=, (count_ev = plr1.event_items.count)
    assert   plr1.event_items.include?(evit1)
    assert_operator 1, :<=, (count_ar = plr1.artists.count), 'check has_many artists and also fixtures'
    assert_operator 1, :<=, (count_mu = plr1.musics.count), 'check has_many musics and also fixtures'
    assert_equal 1,         plr1.instruments.count, 'check has_many instruments and also fixtures'

    assert_no_difference("plr1.event_items.count", "Test of distinct?"){
      assert_difference("plr1.musics.count", 1, "Musics association count..."){
        assert(plr1.artist_music_plays << ArtistMusicPlay.new(event_item: evit1, artist: art0, music: mus0, instrument: Instrument.first))
      }
    }

    assert_no_difference("ArtistMusicPlay.count", "Test of dependent"){
      assert_raises(ActiveRecord::DeleteRestrictionError){
        plr1.destroy
      }
    }
  end
end
