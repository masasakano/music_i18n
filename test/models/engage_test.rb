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
require 'test_helper'

class EngageTest < ActiveSupport::TestCase
  test "dependent and unique and CHECK" do
    assert_raises(ActiveRecord::RecordInvalid){ Engage.create! }
    assert_raises(ActiveRecord::RecordInvalid){ Engage.create!(music:  musics( :music99)) }
    assert_raises(ActiveRecord::RecordInvalid){ Engage.create!(artist: artists(:artist99)) }
    obj = Engage.create!(music:  musics(:music99), artist: artists(:artist99), engage_how: engage_hows(:engage_how_1), year: 2000)
    obj2 = obj.dup

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ obj2.save! } # PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_engages_on_4_combinations\"\nDETAIL:  Key (artist_id, music_id, engage_how_id, year)=(1039544042, 263076983, 949583562, 2000) already exists.
    obj2.year = nil
    assert_nothing_raised{ obj2.save! }
    obj3 = obj2.dup
    assert_raises(ActiveRecord::RecordInvalid){ obj3.save! }

    ## The following "combined" unique index constraint has been removed.
    # assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ obj2.save! }  # PG::UniqueViolation (though it is caught by Rails validation before passed to the DB) => "Validation failed: Music has already been taken"
    assert obj2.valid?

    obj2.music = musics(:music1)
    assert     obj2.valid?
    obj2.year = 0
    assert_not obj2.valid?
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ obj2.save! }  # "Validation failed: Year (0) must be positive."
    obj2.year = 2000
    assert_nothing_raised{ obj2.save! }

    obj22 = obj2.dup
    obj22.engage_how = engage_hows(:engage_how_3) # to check if it can be saved if engage_how is changed.
    obj22.engage_how = engage_hows(:engage_how_unknown) # to check if it can be saved if engage_how is changed.
    assert_nothing_raised{ obj22.save! }

    obj23 = obj2.dup
    obj23.engage_how = engage_hows(:engage_how_composer) # to check if it can be saved after engage_unknown is saved.
    assert obj23.valid?
    assert_nothing_raised{ obj23.save! }

    obj2.destroy
    obj22.destroy
    obj23.destroy

    # obj == Engage(music99, artist99)
    obj.reload
    mus1  = musics(  :music1)
    art1  = artists(:artist1)
    mus99 = musics(  :music99)
    art99 = artists(:artist99)
    assert_equal [mus99], art99.musics.to_a
    assert_equal [art99], mus99.artists.to_a
    art99.destroy  # => destroy music1-asociation dependently
    #assert_not obj.valid?   # because it has been destroyed (reload is essential after save!)  # NOTE: this test used to succeed before Rails-7.2
    assert_raises(ActiveRecord::RecordNotFound){ Engage.find obj.id }

    obj3 = Engage.create!(music: mus99, artist: art1, engage_how: engage_hows(:engage_how_1))
    assert Engage.find(obj3.id)
    obj3.reload
    mus99.destroy
    #assert_not obj3.valid?  # because it has been destroyed (reload is essential after save!)  # NOTE: this test used to succeed before Rails-7.2
    assert_raises(ActiveRecord::RecordNotFound){ Engage.find obj3.id }
  end

  test "callback adds an UnknownEngage" do
    ehk = engage_hows(:engage_how_unknown)
    assert_equal 'UnknownEngaging', ehk.translations_with_lang('en')[0].title

    #assert_raises(ActiveRecord::RecordInvalid){ Engage.create!(music:  musics(:music99), artist: artists(:artist99)) }
    obj = Engage.create!(music:  musics(:music99), artist: artists(:artist99))
    assert_match( /Unknown/i, obj.engage_how.titles(langcode: 'en')[0] )
  end

  test "self.find_and_set_one_harami1129" do
    artist0    = artists(:artist_rcsuccession)
    artist0_ja = translations(:artist_rcsuccession_ja)
    h1129_rc0  = harami1129s(:harami1129_rcsuccession) # 雨上がりの夜空に, RCサクセション

    assert_equal artist0.title, artist0_ja.title, 'sanity test'
    assert_equal artist0.title, h1129_rc0.singer, 'sanity test'

    ## :harami1129_rcsuccession is already internally inserted, but not populated, so it is populated here.
    # h1129_rc0.fill_ins_column!
    assert_difference('HaramiVid.count', 1) do
      assert_difference('Artist.count', 0) do
        assert_difference('Music.count + Engage.count', 2) do
          # Should create a new HaramiVid, Music, and thus Engage, but not Artist
          h1129_rc0.populate_ins_cols_default(messages: [], dryrun: false)
        end
      end
    end
    engage0 = h1129_rc0.engage
    assert_equal artist0, engage0.artist, 'sanity test'
    music0 = engage0.music  # should be a new one, i.e., it does not exist in Fixtures.
    assert_equal 1,               music0.translations.count
    refute       h1129_rc0.song.blank?
    assert_equal h1129_rc0.song, music0.title

    music_ja1 = "僕の好きな先生"
    h1129 = Harami1129.create!(
      singer: h1129_rc0.singer+" ",  # "RCサクセション "
      song: music_ja1,               # "僕の好きな先生"
      release_date: "2020-09-22",
      title: "【テストピアノ】僕の好きな先生弾いた【RCサクセション】",
      link_root: "RC999999",
      link_time: "0",
      #ins_singer: 
      #ins_song: 
      #ins_release_date: 2019-09-22
      #ins_title: 【都庁ピアノ】都庁で弾いたら、自己最多の方が聴いてくれた!!【ストリートピアノ】
      #ins_link_root: youtu.be/RC999999
      #ins_link_time: 0
      #ins_at: 
      note: "test of 僕の好きな先生 Harami1129",
      id_remote: Harami1129.where.not(id_remote: nil).order(id_remote: :desc).first.id_remote.to_i+1,
      last_downloaded_at: Time.now-10,
      #orig_modified_at: 2020-10-25 21:46:00
      #checked_at:
      #engage:
      #harami_vid:
    )

    h1129.fill_ins_column!  # internally inserted.
    h1129.save!  # not sure if necessary

    # When Music/Artist already exists with no Engage with Harami1129
    music_boku = Music.create_with_orig_translation!(artist: artist0, translation: {title: music_ja1, langcode: 'ja'})
    #music_boku = Music.create_with_orig_translation!(artist: artist0, translation: {title: 'Dummy', alt_title: music_ja1, langcode: 'ja'})
    assert_equal music_ja1, music_boku.title_or_alt(prefer_alt: true), 'sanity check'

    # Test of find_identical_engage_for_harami1129()
    eng11 = Engage.find_identical_engage_for_harami1129(h1129, messages: [])
    assert_nil  eng11, "No Engage with Singer/Song WITH Harami1129, hence it should be nil, but: "+eng11.inspect

    # If there is a matching Engage:
    begin
      eng_tmp = Engage.create!(artist: artist0, music: music_boku, engage_how: EngageHow.first)
      h1129one = harami1129s(:harami1129one)
      h1129one.engage = eng_tmp
      h1129one.save!
      assert_equal 1, eng_tmp.harami1129s.count, 'sanity check'
      eng_tmp.reload

      eng12 = Engage.find_identical_engage_for_harami1129(h1129, messages: [])
      refute_nil  eng12, "An Engage with Singer/Song WITH Harami1129 exists, hence it should exist, but: "+eng12.inspect
      assert_equal artist0,    eng12.artist
      assert_equal music_boku, eng12.music
    ensure
      h1129one.engage = nil
      h1129one.save!
      eng_tmp && eng_tmp.destroy!
    end

    # Test of dryrun: true
    eng13 = Engage.find_and_set_one_harami1129(h1129, updates: [], dryrun: true)
    assert eng13.new_record?
    assert_equal artist0,    eng13.artist  # RCサクセション
    assert_equal music_ja1,  eng13.music.unsaved_translations.first.title

    music_boku.destroy!  ## Matching Music "僕の好きな先生" completely destroyed

    # Test for a proper run (populate a Harami1129 with a new song)
    eng21 = nil
    assert_difference('HaramiVid.count', 0) do
      assert_difference('Artist.count', 0) do
        assert_difference('Music.count + Engage.count', 2) do
          # Should create a new HaramiVid, Music, and thus Engage, but not Artist
          eng21 = Engage.find_and_set_one_harami1129(h1129, updates: [], dryrun: false)
        end
      end
    end
    assert_equal artist0, eng21.artist  # RCサクセション
    assert_equal music_ja1, eng21.music.title  # "僕の好きな先生"

    # Populate another Harami1129 with same Singer & Song
    h112b = h1129.dup
    h112b.title = "Temporary"
    h112b.link_root = "newLink888"
    h112b.id_remote += 1
    h112b.ins_title = nil
    h112b.ins_link_root = nil
    h112b.engage_id = nil
    h112b.harami_vid_id = nil
    h112b.save!
    h112b.fill_ins_column!  # internally inserted.
    h112b.save!  # not sure if necessary

    eng31 = nil
    assert_difference('HaramiVid.count', 0) do
      assert_difference('Artist.count', 0) do
        assert_difference('Music.count + Engage.count', 0) do  # no difference!
          eng31 = Engage.find_and_set_one_harami1129(h112b, updates: [], dryrun: false)
        end
      end
    end
    assert_equal artist0, eng31.artist  # RCサクセション
    assert_equal music_ja1, eng31.music.title  # "僕の好きな先生"
    assert_equal eng21, eng31
  end  # test "self.find_and_set_one_harami1129" do


  test "pupulating at the model level" do
    # harami1129s(:harami1129_rcsuccession)
    # harami_vids(:harami_vid_50anni)
    # artists(:artist_rcsuccession)
    # musics(:music_how)
    # musics(:music_story)
    # musics(:music_kampai)
    # engages(:engage_ai_story)
    # engages(:engage_artist2_music_how)

    all_ins = %i(ins_singer ins_song ins_release_date ins_title ins_link_root ins_link_time)

    ## Existing one
    harami1129 = harami1129s(:harami1129_ai)
    artist_ai = artists(:artist_ai)
    upd_ai = artist_ai.updated_at
    tit_ai = artist_ai.title

    ## Existing one (no updates specified)
    assert_no_difference('HaramiVid.count*10000+Artist.count*1000+Music.count*100*Engage.count*10') do
      Engage.find_and_set_one_harami1129(harami1129, updates: [])
    end
    artist_ai.reload
    assert_equal  upd_ai, artist_ai.updated_at
    assert_equal  tit_ai, artist_ai.title
    assert_not_equal artist_ai.title,        harami1129.singer  # Ai <=> AI
    assert_equal     artist_ai.title.upcase, harami1129.singer.upcase

    ## Existing one (full updates specified)
    assert_no_difference('HaramiVid.count*10000+Artist.count*1000+Music.count*100*Engage.count*10') do
      Engage.find_and_set_one_harami1129(harami1129, updates: Harami1129::ALL_INS_COLS)
    end
    artist_ai.reload
    assert_equal  upd_ai, artist_ai.updated_at
    assert_equal  tit_ai, artist_ai.title

    ## New one
    harami1129_3 = harami1129s(:harami1129_3)
    harami1129_3.fill_ins_column!
    engage = nil
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 1110) do
      # For Harami1129 one without engage_id, updates is ignored,
      engage = Engage.find_and_set_one_harami1129(harami1129_3, updates: [])
    end
    assert_nil harami1129_3.engage
    assert_not engage.engage_how.unknown? # For Harami1129, a newly created EngageHow is NOT unknown.
    assert_equal harami1129_3.song,   engage.music.title
    assert_equal harami1129_3.singer, engage.artist.title

    # repeated action does nothing
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 0) do
      engage = Engage.find_and_set_one_harami1129(harami1129_3, updates: Harami1129::ALL_INS_COLS)
    end
    # puts "HaramiVid.count=#{HaramiVid.count}"
    # puts "Artist.count=#{Artist.count}"
    # puts "Music.count=#{Music.count}"
    # puts "Engage.count=#{Engage.count}"

    ## New one (where 2 Music-s with lower and upper-cases exist)
    engage.engage_how = engage_hows(:engage_how_composer)
    engage.save!
    music2 = engage.music.dup  # Makes Music with only the difference of title.upcase
    music2.translations.clear
    music2.unsaved_translations << Translation.new(langcode: 'en', is_orig: true, title: engage.music.title.upcase)
    music2.save!

    # case-insensitive-match with the artist has a priority over case-sensitive-match WITHOUT the artist
    harami1129_3.ins_song.upcase!  # ins_song in Harami1129 forcibly modified.
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 0) do
      engage2 = Engage.find_and_set_one_harami1129(harami1129_3, updates: Harami1129::ALL_INS_COLS)
    end

    ## multiple for (exact: false, scoped:artists), but only one for (exact: true, scoped:artists)
    engage2 = nil
    music2.artists << engage.artist
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 0) do
      engage2 = Engage.find_and_set_one_harami1129(harami1129_3, updates: Harami1129::ALL_INS_COLS)
      assert_not_equal engage, engage2
      assert_equal     engage.music.title.upcase, engage2.music.title
      assert     engage2.engage_how.unknown?  # EngageHow of a newly created Engage is always unknown.
    end

    ## multiple for (exact: false), but only one for (exact: true), where no artist association is defined in Engage
    engage.destroy!
    engage2.destroy!
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 10) do
      engage2 = Engage.find_and_set_one_harami1129(harami1129_3, updates: Harami1129::ALL_INS_COLS)
      assert_equal     harami1129_3.ins_song, engage2.music.title
      assert_not engage2.engage_how.unknown? # For Harami1129, a newly created EngageHow is NOT unknown.
    end

    ## multiple for (exact: false), but none for (exact: true), where no artist association is defined in Engage
    engage2.destroy!
    music2.reload
    assert_equal music2.title.upcase, music2.title  # sanity check
    tra = music2.translations.first
    tra.title = tra.title.sub!(/...$/){$&.downcase}  # forcibly modified.
    tra.save!
    music2.reload
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 10) do
      engage2 = Engage.find_and_set_one_harami1129(harami1129_3, updates: Harami1129::ALL_INS_COLS)
      assert_not_equal harami1129_3.ins_song,          engage2.music.title
      assert_equal     harami1129_3.ins_song.downcase, engage2.music.title.downcase
      assert_not engage2.engage_how.unknown? # For Harami1129, a newly created EngageHow is NOT unknown.
    end

    # year or EngageHow should not matter; as long as artist&musc match, Engage unchanges
    engage2.update!(year: 1900, engage_how: engage_hows(:engage_how_composer))
    assert_difference('HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10', 0) do
      engage2 = Engage.find_and_set_one_harami1129(harami1129_3, updates: Harami1129::ALL_INS_COLS)
    end
  end

  test "fail to destroy when Harami1129 association exists" do
    eng = engages( :engage_ai_story )
    assert eng.harami1129s.exists?
    assert_raises(ActiveRecord::DeleteRestrictionError){
      eng.destroy! }

    # destroying associations
    eng.harami1129s.each do |h1129|
      h1129.engage = nil
      h1129.save!
    end
    assert_not eng.harami1129s.exists?

    eng.reload  # reload is essential! (otherwise, ActiveRecord::DeleteRestrictionError)
    assert_nothing_raised{
      eng.destroy! }
  end

  test "pupulating a new one at the model level" do
    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    ## New one (ins_* are nil)
    harami1129_ewf = harami1129s(:harami1129_ewf)
    engage = nil
    assert_difference(str_equation, 10) do
      engage = Engage.find_and_set_one_harami1129(harami1129_ewf, updates: Harami1129::ALL_INS_COLS)
      assert engage.unknown?
      assert engage.artist.unknown?
      assert engage.music.unknown?
    end

    harami1129_ewf.fill_ins_column!
    assert_difference(str_equation, 1110) do
      engage = Engage.find_and_set_one_harami1129(harami1129_ewf, updates: Harami1129::ALL_INS_COLS)
      assert_equal harami1129_ewf.ins_singer,        engage.artist.title
      assert_equal harami1129_ewf.ins_song,          engage.music.title
      assert_not engage.engage_how.unknown? # For Harami1129, a newly created EngageHow is NOT unknown.
    end

    # repeated null actions
    assert_difference(str_equation, 0) do
      engage = Engage.find_and_set_one_harami1129(harami1129_ewf, updates: [])
    end
    assert_difference(str_equation, 0) do
      engage = Engage.find_and_set_one_harami1129(harami1129_ewf, updates: Harami1129::ALL_INS_COLS)
    end
  end

  test "find_and_set_one_harami1129 for existing" do
    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'

    ## Existing (and name-wise unrelated) Engage
    eng_orig = engages(:engage_ai_story)
    musics(:music_story).translations.where.not(langcode: "en").each do |mdl|
      mdl.destroy!  # Ensure no ja translations.
    end

    h1129 = Harami1129.new(ins_singer: 'naiyo_a', ins_song: 'naiyo_m', engage: eng_orig)
    eng = Engage.find_and_set_one_harami1129(h1129, updates: Harami1129::ALL_INS_COLS, dryrun: true)
    assert_equal eng_orig.artist.title, eng.columns_for_harami1129[:be4][:ins_singer]
    assert_equal eng_orig.music.title,  eng.columns_for_harami1129[:be4][:ins_song]

    ## When a new ins_singer/song does not include "The" but the DB does.
    eng_orig = engages(:engage_proclaimers_light)
    h1129 = Harami1129.new(ins_singer: 'proclaimers', ins_song: 'light')
    eng = Engage.find_and_set_one_harami1129(h1129, updates: Harami1129::ALL_INS_COLS, dryrun: true)
    assert_nil  eng.columns_for_harami1129[:be4][:ins_singer]
    assert_nil  eng.columns_for_harami1129[:be4][:ins_song]
    assert_equal eng_orig.artist.title, eng.columns_for_harami1129[:aft][:ins_singer]
    assert_equal eng_orig.music.title,  eng.columns_for_harami1129[:aft][:ins_song]
  end
end
