# coding: utf-8
# == Schema Information
#
# Table name: instruments
#
#  id                                    :bigint           not null, primary key
#  note                                  :text
#  weight(weight for sorting for index.) :float            default(999.0), not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#
# Indexes
#
#  index_instruments_on_weight  (weight)
#
require "test_helper"

class InstrumentTest < ActiveSupport::TestCase
  test "fixtures" do
    tra = translations(:instrument_vocal_en)
    assert_equal "Vocal", tra.title
    assert_equal "en",   tra.langcode
    assert_equal "InstrumentVocalEn", tra.note

    tra = translations(:instrument_vocal_ja)
    assert_equal "ja",   tra.langcode
    assert_equal "歌手", tra.title
    assert_equal 10,       tra.translatable.weight

    tra = translations(:instrument_other_ja)
    assert_equal "その他", tra.title

    assert_match(/\bpiano\b/i, Instrument.default(:HaramiVid).title(langcode: "en"))
  end

  test "weight" do
    mdl = instruments(:instrument_piano)
    user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb
    ## Model contains validates_presence_of, but for some reason (maybe because of DB default?), "allow_nil: true" works...

    #assert_raises(ActiveRecord::RecordInvalid){
    #  Instrument.create!( note: "") }     # When no entries have the default value, this passes!
    assert_raises(ActiveRecord::RecordInvalid){
      Instrument.create!( weight: nil) }
    assert_raises(ActiveRecord::RecordInvalid){
      Instrument.create!( weight: "abc") }
    assert_raises(ActiveRecord::RecordInvalid){
      Instrument.create!( weight: -4) }
  end
  
  test "uniqueness" do
    unique_weight = Instrument.order(weight: :desc).first.weight
    refute_equal Float::INFINITY, unique_weight
    hsin = {langcode: "en", weight: unique_weight+1, title: "for-val03-#{__method__.to_s}", note: "inst3"}
    inst3 = Instrument.create_basic!(**hsin)
    inst4 = nil
    assert_raises(ActiveRecord::RecordInvalid){
      inst4 = Instrument.create_basic!(**(hsin.merge({weight: inst3.weight+1, note: "inst4"}))) }
    assert_nothing_raised{
      inst4 = Instrument.create_basic!(**(hsin.merge({title: inst3.title+"-4", weight: inst3.weight+1, note: "inst4"}))) }

    assert inst4.valid?
    tra = inst4.translations.first
    assert tra.valid?

    tra.title = hsin[:title]
    refute tra.valid?
    assert inst4.valid?
    assert_nothing_raised{ inst4.update!(note: 'something44') }
  end

  test "associations via ArtistMusicPlayTest" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")
    plr0 = play_roles(:play_role_conductor)

    ins1  = instruments(:instrument_piano)
    evit1 = event_items(:evit_1_harami_budokan2022_soiree)
    assert_operator 1, :<=, ins1.artist_music_plays.count, 'check has_many artist_music_plays and also fixtures'
    assert_operator 1, :<=, (count_ev = ins1.event_items.count)
    assert   ins1.event_items.include?(evit1)
    assert_operator 1, :<=, (count_ar = ins1.artists.count), 'check has_many artists and also fixtures'
    assert_operator 1, :<=, (count_mu = ins1.musics.count), 'check has_many musics and also fixtures'
    assert_operator 1, :<=, ins1.play_roles.count, 'check has_many play_roles and also fixtures'

    assert_nil(ins1.artist_music_plays << ArtistMusicPlay.new(event_item: evit1, artist: art0, music: mus0, play_role_id: -3))
    assert(    ins1.artist_music_plays << ArtistMusicPlay.new(event_item: evit1, artist: art0, music: mus0, play_role: plr0))
    assert_equal count_mu+1, ins1.musics.count
    assert_equal count_ev,   ins1.event_items.count, 'distinct?'

    assert_no_difference("ArtistMusicPlay.count", "Test of dependent"){
      assert_raises(ActiveRecord::DeleteRestrictionError){
        ins1.destroy
      }
    }
  end
end
