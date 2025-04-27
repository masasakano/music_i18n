# coding: utf-8
# == Schema Information
#
# Table name: musics
#
#  id                                         :bigint           not null, primary key
#  memo_editor(Internal-use memo for Editors) :text
#  note                                       :text
#  year                                       :integer
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  genre_id                                   :bigint           not null
#  place_id                                   :bigint           not null
#
# Indexes
#
#  index_musics_on_genre_id  (genre_id)
#  index_musics_on_place_id  (place_id)
#
# Foreign Keys
#
#  fk_rails_...  (genre_id => genres.id)
#  fk_rails_...  (place_id => places.id)
#
require 'test_helper'

class MusicTest < ActiveSupport::TestCase
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:artist1)
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
  end

  test "CHECK constraints and on_delete dependency" do
    placei = Place.create!(prefecture: Prefecture.last)
    genrei = Genre.create!()
    obj = Music.new(place: placei, genre: genrei)

    ## Check constraints
    
    obj.year = -1
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ obj.save! }
    # DRb::DRbRemoteError: PG::CheckViolation: ERROR:  new row for relation "musics" violates check constraint "check_musics_on_year"

    obj.year = nil
    assert_nothing_raised{ obj.save! }

    assert_raises(ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){ placei.destroy }
    # DRb::DRbRemoteError: PG::ForeignKeyViolation: ERROR:  update or delete on table "places" violates foreign key constraint "fk_rails_2b42755a33" on table "musics"

    assert_raises(ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){ genrei.destroy }

    assert_difference('Engage.count', -1) do
      musics(:music2).destroy
    end

  end

  test "create with translation" do
    title_existing = Translation.where(translatable_type: "Music", langcode: "en", is_orig: true).first.title_or_alt
    bwt_new = Music.create_with_orig_translation!({}, translation: {title: title_existing, langcode: 'en'})
    assert_equal title_existing, bwt_new.title, "Music can have an existing title, as long as the Artist differs, but..."

    tit = 'a random new music'
    bwt_new = Music.create_with_orig_translation!({}, translation: {title: tit, langcode: 'en'})
    assert_equal tit, bwt_new.title
  end

  test "unknown" do
    assert Music.unknown
    assert_operator 0, '<', Music.unknown.id
    obj = Music[/UnknownMus/i, 'en']
    assert_equal obj, Music.unknown
    assert obj.unknown?
  end

  test "self.find_all_by_title_plus" do
    music_light = musics :music_light
    music_light_en = translations :music_light_en
    place_uk_unknown = places :unknown_place_unknown_prefecture_uk
    genre_pop = genres :genre_pop

    ## sanity checks of the fixture
    assert_equal 1994,             music_light.year
    assert_equal place_uk_unknown, music_light.place
    assert_equal genre_pop,        music_light.genre

    rela = Music.find_all_by_title_plus(["The Light"])
    assert_operator 1, '<=', rela.count
    assert_equal    1,       rela.count
    music =                   Music.find_by_title_plus(["The Light"])
    assert_equal music_light, music
    assert_equal :exact,       music.match_method
    assert_equal "Light, The", music.matched_string # Definite article moved in the matched string
    assert_equal music_light, Music.find_by_title_plus(["the light"])

    assert_equal music_light, Music.find_by_title_plus(["Light, The"])
    assert_equal music_light, Music.find_by_title_plus(["light, the"], match_method_upto: :exact_ilike)
    assert_nil                Music.find_by_title_plus(["light, the"], match_method_upto: :exact)
    assert_nil                Music.find_by_title_plus(["light"],      match_method_upto: :exact_ilike)
    assert_equal music_light, Music.find_by_title_plus(["light"]) #Def:match_method_upto: :optional_article_ilike,

    moderator_tr  = users(:user_moderator_translation)
    tr_kampai_en3 = translations(:music_kampai_en3)
    assert_equal moderator_tr.id, tr_kampai_en3.create_user_id, sprintf('moderator ID=%d is not assigned to create_id=%d.', moderator_tr.id, tr_kampai_en3.create_user_id)

    sysadmin = users( :user_sysadmin )
    tra_en = music_light.translations.first
    assert_equal music_light_en, tra_en             # sanity check of Fixture
    assert_equal 'en',        tra_en.langcode       # sanity check of Fixture
    assert_equal sysadmin.id, tra_en.create_user_id # sanity check of Fixture
    tra_jp = tra_en.dup
    tra_jp.langcode = 'ja'
    assert_difference('Translation.count', 1) do
      tra_jp.save!
    end
    # Now there are 2 Translations (en and ja) with identical information.

    #sign_in @editor
    rela = Music.find_all_by_title_plus(["The Light"])
    assert_equal    2,       rela.count
    rela = Music.find_all_by_title_plus(["The Light"], uniq: true)
    assert_equal    1,       rela.count

    assert_equal music_light, Music.find_by_title_plus(["The Light"])
    assert_nil                Music.find_by_title_plus(["naiyo"*3, "光１２３"])
    tra_jp.alt_title = '光123'
    tra_jp.save!
    assert_equal music_light, Music.find_by_title_plus(["The Light"]) # Existing one still matches.
    music =                   Music.find_by_title_plus(["naiyo"*3, "光１２３"])
    assert_equal music_light, music
    assert_equal '光123',     music.matched_string  # This time, matched_string changed
    assert_nil                Music.find_by_title_plus(["naiyo"*3, "光"])
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光"], match_method_upto: :include)

    # With a different place from the existing, nothing is matched, depending where.
    # The existing is UnknownPrefecture_in_UK, hence anywhere in the UK should match.
    perth_uk  = places( :perth_uk )
    perth_aus = places( :perth_aus )
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"])  # Template
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], place: nil)
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], place: Place.unknown)
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], place:    perth_uk)
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], place_id: perth_uk.id)
    assert_nil                Music.find_by_title_plus(["naiyo"*3, "光123"], place:    perth_aus)
    assert_nil                Music.find_by_title_plus(["naiyo"*3, "光123"], place_id: perth_aus.id)

    # With a different year from the existing, nothing is matched.
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], year: nil)
    assert_nil                Music.find_by_title_plus(["naiyo"*3, "光123"], year: 1877)

    # With a different Genre from the existing, it still matches.
    genre_classic = genres( :genre_classic )
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], genre: nil)
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], genre: Genre.unknown)
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], genre: genre_classic)
    assert_equal music_light, Music.find_by_title_plus(["naiyo"*3, "光123"], genre_id: genre_classic.id)
  end

  test "self.find_all_by_title_plus with joins" do
    art_pro = artists :artist_proclaimers
    music_light = musics :music_light
    music_light_en = translations :music_light_en
    place_uk_unknown = places :unknown_place_unknown_prefecture_uk
    genre_pop = genres :genre_pop

    music =                   Music.find_by_title_plus(["Light"], artists: art_pro, match_method_upto: :include)
    assert_equal music_light, music
    rela = Music.find_all_by_title_plus(["Light"], artists: art_pro, match_method_upto: :include)
    assert_equal    1,       rela.count
    rela = Music.find_all_by_title_plus(["Ligh"],  artists: art_pro, match_method_upto: :include)
    assert_equal    1,       rela.count

    tra_new = Translation.new(langcode: 'en', title: 'Lighting, The')
    mu_new = Music.new
    mu_new.unsaved_translations << tra_new
    mu_new.save!
    mu_new.artists << artists( :artist2 )
    assert_equal    2, Translation.select_regex(:title, /Light/, translatable_type: 'Music').size # Providing there are no new Fixtures that contain this name!
    rela = Music.find_all_by_title_plus(["Lighting"],                match_method_upto: :include)
    assert_equal    1,       rela.count
    rela = Music.find_all_by_title_plus(["Light"],                   match_method_from: :include, match_method_upto: :include)
    assert_equal    2,       rela.count
    rela = Music.find_all_by_title_plus(["Light"], [:title, :alt_title, :ruby], artists: art_pro, match_method_from: :include, match_method_upto: :include)
    assert_equal    1,       rela.count
    assert_equal music_light, rela.first
    assert_nil Music.find_by_title_plus(["Light"], [:ruby, :alt_romaji], artists: art_pro, match_method_from: :include, match_method_upto: :include)
  end

  # Order should be by EngageHow.weight, contribution, year, birth_year
  test "sorted_artists" do
    mus = Music.create_basic!(title: "test-#{__method__}-1", langcode: "en", is_orig: true, genre: Genre.unknown)
    how1 = EngageHow.order(:weight)[0]
    how2 = EngageHow.order(:weight)[1]
    how3 = EngageHow.order(:weight)[2]
    how4 = EngageHow.order(:weight)[3]

    art1 = artists(:artist1)
    art2 = artists(:artist2)
    art3 = artists(:artist3)
    art4 = artists(:artist4)

    engs = {}.with_indifferent_access

    engs[:a1h2] = mus.find_and_update_or_add_engage!(art1, how2, year: nil, contribution: nil, note: "a1h2")
    assert             engs[:a1h2].id
    assert_equal art1, engs[:a1h2].artist
    assert_equal how2, engs[:a1h2].engage_how
    assert_nil         engs[:a1h2].contribution
    assert_equal 1,    mus.engages.size
    assert_equal "a1h2", mus.engages.first.note
    assert_equal engs[:a1h2], mus.engages.first

    mus.find_and_update_or_add_engage!(art1, how2, year: nil, contribution: nil, note: nil)  # no change.
    assert_equal 1,    mus.engages.size
    assert_equal "a1h2", mus.engages.first.note, "note should not be updated"  # test of find_and_update_or_add_engage!

    assert_raises(ActiveRecord::RecordInvalid){  # test of find_and_update_or_add_engage!
      mus.find_and_update_or_add_engage!(art1, how2, year: nil, contribution: -3, note: nil)}

    assert_equal art1, mus.sorted_artists.first
    assert_equal art1, mus.most_significant_artist

    engs[:a1h3] = mus.find_and_update_or_add_engage!(art1, how3, year: 2003, contribution: nil, note: "a1h3")
    assert_equal 2,    mus.engages.size
    assert_equal art1, mus.sorted_artists.first
    assert_equal art1, mus.most_significant_artist

    engs[:a2h4] = mus.find_and_update_or_add_engage!(art2, how4, year: 1999, contribution: 0.5, note: "a2h4")
    assert_equal 3,    mus.engages.size, "art1 is higher because of how2 < how4"
    assert_equal art1, mus.sorted_artists.first
    assert_equal art1, mus.most_significant_artist

    assert_nil (engs[:a1h2].year || engs[:a1h2].contribution)
    engs[:a2h2] = mus.find_and_update_or_add_engage!(art2, how2, year: 1999, contribution: nil, note: "a2h2")
    assert_equal 4,    mus.engages.size

    engs[:a1h2].update!(year: 2010)
    assert_equal art2, mus.most_significant_artist
    assert_equal art2, mus.sorted_artists.first, "art1 is lower because of year"

    engs[:a1h2].update!(year: 1920, contribution: 0.1)
    engs[:a2h2].update!(year: 1999, contribution: 0.9)
    assert_equal art2, mus.sorted_artists.first, "art2 is higher because of contribution regardless of year"

    engs[:a1h2].update!(year: 1920, contribution: 0.5)
    engs[:a2h2].update!(year: 1999, contribution: 0.5)
    mus.engages.reset
    assert_equal art1, mus.sorted_artists.first, "art1 is higher because of year with the same contribution"

    engs[:a1h2].update!(year: 2010, contribution: nil)
    engs[:a2h2].update!(year: 1999, contribution: 0.9)
    mus.reload
    ## print "DEBUG:3243:"; p [mus.engages.where(artist_id: art1).joins(:engage_how).order("engage_hows.weight").first, mus.engages.where(artist_id: art2).joins(:engage_how).order("engage_hows.weight").first].map{|i| [i.engage_how.weight, i.contribution, i.year]}.inspect
    #assert_equal art1, mus.sorted_artists.first, "art1 is higher because of nil contribution"
    ########### For some reason thid does not work........  TODO
  end

  test "populate_csv" do
    strin = <<EOF
 # comment
1:1/20[20th],糸,,Ito,Thread,1992,,,Miyuki Nakajima,ja,クラシック,compo,one of the longest hits of J-Pop
2:2/20[19th],Shake,,,Shake,1996,,,SMAP,en
3,子守唄,コモリウタ,Komoriuta,,,香川県,,,en,
# ja-title with no en-title but with "en" means ja-title has is_orig=false.
   
EOF

    assert       artists(:artist_unknown).id
    assert_equal artists(:artist_unknown), Artist.unknown
    reths = nil
    mus_ito = nil
    mus_shake = nil
    art_nakajima = nil
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 7323) do # Because the 3rd row is Artist.unknown, which already exists.
      reths = Music.populate_csv(strin)
    end
    begin
      assert_equal 3, reths[:musics].compact.size
      assert_equal 3, reths[:artists].compact.size
      assert_equal 3, reths[:engages].compact.size

      mus = reths[:musics][1]
      mus_ito = mus
      assert_equal 'Thread', mus.title(langcode: 'en')
      assert_equal '糸',     mus.title(langcode: 'ja')
      assert_equal 'Ito',    mus.romaji(langcode: 'ja')
      assert_equal 'one of the longest hits of J-Pop', mus.note
      assert_equal genres(:genre_classic), mus.genre, 'Regexp match should work for Genre, but?'
      mus.reload  # Essential!
      tras = mus.best_translations
      assert_equal true,  tras['ja'].is_orig
      assert_equal false, tras['en'].is_orig
      assert_equal places(:unknown_place_unknown_prefecture_japan), mus.place

      art = reths[:artists][1]
      art_nakajima = art
      assert_equal 'Miyuki Nakajima', art.title(langcode: 'en')
      assert_equal places(:unknown_place_unknown_prefecture_japan), art.place
      assert_nil   art.note

      eng = reths[:engages][1]
      assert_equal engage_hows(:engage_how_composer), eng.engage_how, 'Regexp match should work for EngageHow, but?'

      mus = reths[:musics][2]
      mus_shake = mus
      assert_equal 'Shake', mus.title(langcode: 'en')
      assert_equal 'Shake', mus.title(langcode: 'ja')
      assert_nil            mus.romaji(langcode: 'ja')
      assert_nil   mus.note
      mus.reload  # Essential!
      tras = mus.best_translations
      assert_equal false, tras['ja'].is_orig
      assert_equal true,  tras['en'].is_orig
      assert_equal Place.unknown, mus.place

      art = reths[:artists][2]
      assert_equal 'SMAP', art.title(langcode: 'en')
      assert_equal Place.unknown, art.place

      ### Row 3 (0th line is skipped)
      art = reths[:artists][3]
      assert_equal Artist.unknown, art

      mus = reths[:musics][3]
      mus.reload
      assert_nil             mus.title(langcode: 'en', lang_fallback: false)
      assert_equal '子守唄', mus.title(langcode: 'en')
      assert_equal '子守唄', mus.title(langcode: 'ja')
      assert_equal '子守唄', mus.title
      tras = mus.best_translations
      assert_equal false,  tras['ja'].is_orig
      assert_equal 'コモリウタ', tras['ja'].ruby
      assert_equal 'Komoriuta',  tras['ja'].romaji
      assert_equal genres(:genre_pop),  mus.genre
      assert_equal places(:unknown_place_kagawa_japan), mus.place
      assert_nil   mus.year
      engs = mus.engages
      assert_equal 1, engs.count
      assert_nil      engs[0].year
      assert_equal EngageHow.unknown, engs[0].engage_how
    end

    # Second time with "basically" the same file.
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 0) do
      mus_ito.reload
      mus_ito.place = Place.unknown
      mus_ito.save!
      mus_ito.reload
      assert_equal Place.unknown, mus_ito.place
      mus_shake.reload
      mus_shake.best_translations['en'].destroy!

      reths = Music.populate_csv(strin.sub(/Thread/, 'The thread'))
      mus_ito.reload
      assert_equal 'Thread', mus_ito.title(langcode: 'en'), 'Title should not be updated, but?'
      assert_equal places(:unknown_place_unknown_prefecture_japan), mus_ito.place, 'World-Unknown place should be updated, but?'
      mus = reths[:musics][2]
      mus.reload
      tra = mus.best_translations['en']
      assert_equal 'Shake', tra.title
      assert_equal false,   tra.is_orig, 'is_orig should not be updated, but?'
    end

    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 1101) do
      new_strin = ",てきとう1,\n" # (1st) ruby is added; (3rd) an English title is added
      reths = Music.populate_csv(new_strin)
    end

    ##### Test: If a line contains invalid characters, the DB should roll back.
    ##
    ## Music.populate_csv() handles such CSV without trouble up to the line before
    ## the problematic line (String#each_line does not raise an Exception
    ## due to invalid encoding).
    ## So, some data before the line are saved in the DB even in such cases,
    ## where an Exception is raised.
    ## If everything was inside a transaction, everything should rollback
    ## even in such cases, leaving no changes in the DB. However,
    ## for some reason, "transaction" does not work well here in Rails 6.1
    ## (see comment lines in music.rb for detail).  Therefore
    ## I leave it; n.b., the records before the problematic lines are saved
    ## regardless what happens later in processing.
    ##
    ## Note that the invalid encoding is checked in the Controller.
    ## So, the lack of this safety-net may cause a trouble only when
    ## an unexpected Exception is encountered.
    ##
    #assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 0) do
    #  str_invalid = (",Tekito2,\n"+[0x80, 0x81].pack('C*')+','+"\n").force_encoding('UTF-8')
    #  assert_not str_invalid.valid_encoding?
    #  begin
    #    reths = Music.populate_csv(str_invalid)
    #  rescue
    #  end
    #end

    # Third time with an added Translation to an existing row
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 2000) do
      new_strin = strin.sub(/Komoriuta,/, '\&Lullaby').sub(/糸,/, '\&イト').sub(/,SMAP/, 'SMAP\&') # (1st) ruby is added; (2nd) a Ja artist is added, (3rd) an English title is added
      reths = Music.populate_csv(new_strin)
      assert_equal 'Lullaby', Music['子守唄'].title(langcode: 'en')
    end
  end

  test "populate_csv erroneous cases" do
    strin = <<EOF
 # comment
1,,,Ito,Thread,,,,It is英語であるべきArtist,ja,,,Music is not processed b/c Artist is invalid
2,,,,Shake,should be a number,,SMAP男,,,wrong-Genre,wrong-How,
3,,,Ito,En Title contains 日本語,,,,,ja,,,Music is tried to be processed but invalid
EOF

    reths = nil
    # guess_sex(instr)??
    mus_wrong = nil
    mus_shake = nil
    art_wrong = nil
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 2111) do
      # For the second row (Shake/SMAP男), Artist/Music/Engage are craeted. That is it.
      reths = Music.populate_csv(strin)
    end
    begin
      ### Row 1 (0th line is skipped)
      art = reths[:artists][1]
      assert  art.new_record?, "art="+art.inspect
      assert_match(/Asian char/,  art.errors.full_messages_for(:title)[0]) # "Translation(1st): contains Asian characters (英語であるべき)"
      assert_nil reths[:musics][1] # b/c Artist raises an Error

      ### Row 2 (0th line is skipped)
      art = reths[:artists][2]
      assert_not   art.errors.present?
      assert_nil   art.title(langcode: 'en', lang_fallback: false), "art=#{art.inspect} / art.translations=#{art.translations.inspect}"
      assert_equal 'SMAP男', art.title(langcode: 'ja')
      assert_equal 'SMAP男', art.title
      assert_equal 'ja',     art.orig_langcode
      art.reload
      assert_equal places(:unknown_place_unknown_prefecture_japan), art.place
      assert_equal Sex[:male], art.sex, 'Sex should be guessed to be male but'

      mus = reths[:musics][2]
      assert_equal 'Shake', mus.title(langcode: 'en')
      assert_equal 'Shake', mus.title
      mus.reload
      tras = mus.best_translations
      assert_equal true,  tras['en'].is_orig
      assert_equal Genre.unknown,  mus.genre
      assert_equal places(:unknown_place_unknown_prefecture_world), mus.place
      assert_nil   mus.year
      engs = mus.engages
      assert_equal 1, engs.count
      assert_nil      engs[0].year
      assert_equal EngageHow.unknown, engs[0].engage_how

      ### Row 3 (0th line is skipped)
      art = reths[:artists][3]
      assert_equal Artist.unknown, art

      mus = reths[:musics][3]
      assert  mus.errors.present?
      assert_match(/Asian char/,  mus.errors.full_messages_for(:title)[0]) # "Translation(1st): contains Asian characters (英語であるべき)"
      #assert_nil   mus.title(langcode: 'en'), "mus = #{mus.inspect}"
      assert_equal "En Title contains 日本語", mus.title(langcode: 'en') # unsaved_translations

      assert_equal 2, reths[:musics].compact.size
      assert_equal 3, reths[:artists].compact.size
      assert_equal 1, reths[:engages].compact.size
    end

    assert_raises(CSV::MalformedCSVError){
      reths = Music.populate_csv('a, bcd "ef" g, hi') } # wrong double quotations
  end

  test "associations via ArtistMusicPlayTest" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")

    mus1  = musics(:music_story)
    art1  = artists(:artist_harami)
    evit1 = event_items(:evit_1_harami_budokan2022_soiree)
    assert_operator 1, :<=, mus1.artist_music_plays.count, 'check has_many artist_music_plays and also fixtures'
    assert_operator 1, :<=, (count_ev = mus1.event_items.count)
    assert   mus1.event_items.include?(evit1)
    assert_operator 1, :<=, (count_ar = mus1.play_artists.count), 'check has_many artists and also fixtures'
    #assert_equal 1,         mus1.play_roles.count,  'check has_many play_roles and also fixtures'
    assert_operator 2, :<=, mus1.instruments.count, 'check has_many instruments and also fixtures'

    mus1.artist_music_plays << ArtistMusicPlay.new(event_item: evit1, artist: art0, play_role: PlayRole.first, instrument: Instrument.first)
    assert_equal count_ar+1, mus1.play_artists.count
    assert_equal count_ev,   mus1.event_items.count, 'distinct?'

    assert_difference("ArtistMusicPlay.count", -ArtistMusicPlay.where(music: mus1).count, "Test of dependent"){
      #mus1.harami1129s.destroy_all
      mus1.harami1129s.each do |em|
        em.destroy
      end
      mus1.destroy
    }
  end
end

