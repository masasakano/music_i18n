# coding: utf-8
require 'test_helper'

class MusicsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @music = musics(:music1)
    @editor = users(:user_editor_general_ja)  # Editor can manage.
    # @editor = roles(:general_ja_editor).users.first  # This would occasionally be nil (due to caching implemented in root-Role or sysadmin?)
    @moderator_all   = users(:user_moderator_all)    # Allmighty Moderator can manage.
    @f_artist_name = "artist_name"
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    #sign_in users(:user_two)
    get musics_url
    assert_response :success
    #assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden
    if is_env_set_positive?('TEST_STRICT')  # defined in application_helper.rb
      w3c_validate "Music index"  # defined in test_helper.rb (see for debugging help)
    end  # only if TEST_STRICT, because of invalid HTML for datagrid filter for Range

    mu2   = musics(:music2)    # title(en): Give Peace a Chance Music2
    mu3   = musics(:music3)    # title(en): Give Peace a Chance Music3
    mu99  = musics(:music99)   # title(en): Give Peace a Chance Music99
    mu999 = musics(:music999)  # title(en): Give Peace a Chance Music999
    assert [mu2, mu3, mu99, mu999].all?{ _1.title(langcode: :en).include?("Chance Music") }, 'fixture tests'

    kwd = "ance Music"
    hs = params_hash_for_index_grid(Music, locale: :en, title_ja: kwd, year: (nil..))  # defined in test_helper.rb
    get musics_path, params: hs
    assert_response :success

    hsstats = get_grid_pagenation_stats(langcode: :en, for_system_test: false)  # defined in test_helper.rb
    assert_operator 4, :<=, hsstats[:n_entries]

    tits = css_select(CSSGRIDS[:td_title_en]).map(&:text)
    assert_includes [mu2, mu3].map{ _1.title(langcode: :en)}, tits.first
    assert_equal mu999.title(langcode: :en), tits.last

    ## search based on alt_title with is_orig=false
    # This "nakaguro" caused a problem.
    tit3_ja = "チャンス・ミュージック3"
    assert_difference('Translation.count'){
      mu3.translations << Translation.new(title: mu3.title(langcode: :en), alt_title: tit3_ja, langcode: "ja", is_orig: false, weight: 100)    # title(en): Give Peace a Chance Music3
    }

    kwd = tit3_ja[2..-2]
    hs = params_hash_for_index_grid(Music, locale: :en, title_ja: kwd, year: (nil..))  # defined in test_helper.rb
    get musics_path, params: hs
    assert_response :success

    hsstats = get_grid_pagenation_stats(langcode: :en, for_system_test: false)  # defined in test_helper.rb
    assert_equal 1, hsstats[:n_entries]

    tits = css_select(CSSGRIDS[:td_title_en]).map(&:text)
    assert_equal mu3.title(langcode: :en), tits.last
  end

  test "should get show 1" do
    mu6 = Music.create_basic!(title: "例", langcode: "ja", is_orig: true, year: 2000)   # 1-letter song.
    artist_ai = artists( :artist_ai )
    mu6.engages << Engage.new(artist: artist_ai, engage_how: EngageHow.default(:HaramiVid), year: 2000)

    hvid1 = harami_vids(:harami_vid1)
    hvid1.musics << mu6
    evit1 = hvid1.event_items.first
    assert  evit1, 'sanity check'
    amp1 = ArtistMusicPlay.create!(event_item: evit1, artist: artist_ai, music: mu6, instrument: Instrument.default(:HaramiVid), play_role: PlayRole.default(:HaramiVid))
    hvid1.artist_music_plays.reset

    get music_path(mu6)
    assert_response :success
  end

  test "should create" do
    sign_in @editor
    ModuleWhodunnit.whodunnit  #  just to (potentially) suppress mal-functioning in setting this...
    get musics_url

    artist_ai = artists( :artist_ai )
    engage_how_composer = engage_hows( :engage_how_composer )
    engage_how_player   = engage_hows( :engage_how_player   )

    memoe = "my random memo"
    music = nil
    hstmpl = {
      "langcode"=>"en",
      "is_orig"=>"en",
      "title"=>"The Lｕnch Time",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "place.prefecture_id.country_id"=>Country['AUS'].id.to_s,
      "place.prefecture_id"=>"", "place"=>"", "genre_id"=>Genre.unknown.id.to_s, "year"=>"1984",
      @f_artist_name=>"ＡI  ", "year_engage"=>"",
      "engage_hows"=>["", engage_how_composer.id.to_s, engage_how_player.id.to_s],
      "contribution"=>"",
      "note"=>"", "memo_editor" => memoe}

    # Creation success
    assert_difference('Music.count*10 + Engage.count', 12) do
      post musics_url, params: { music: hstmpl }
      assert_response :redirect
      music = Music.order(:created_at).last
      assert_redirected_to music_url music
      my_assert_no_alert_issued  # defined in /test/test_helper.rb
    end

    assert_equal 'Lunch Time, The', music.title
    assert_equal 'en', music.orig_langcode
    assert music.place.covered_by? Country['AUS']
    assert_equal Genre.unknown,  music.genre
    engs = music.engages
    assert_equal 2, engs.size
    assert_equal artists(:artist_ai).title, engs.first.artist.title  # It is "Ai" in the fixutre (not "AI")
    assert_equal @editor, music.translations.first.create_user, "(NOTE: for some reason, created_user_id is nil) User=#{@editor.inspect} / ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} / PaperTrail.request.whodunnit=#{PaperTrail.request.whodunnit.inspect} / Translation(=music.translations.first)="+music.translations.first.inspect
    assert_equal memoe,   music.memo_editor

    # Failure due to non-existent Artist
    assert_difference('Music.count', 0) do
      post musics_url, params: { music: hstmpl.merge({@f_artist_name=>'naiyo'}) }
      assert_response :success
    end
    sign_out @editor
  end

  test "should update" do
    sign_in @editor

    music_orig = @music.dup
    artist2 = artists( :artist2)
    engage_how1 = engage_hows( :engage_how_1 )
    genre_c = genres( :genre_classic )

    # Update success
    hs_tmpl = {  # Neither Artist nor Translation-related is accepted in #edit
      "place.prefecture_id.country_id"=>Country['AUS'].id.to_s,
      "place.prefecture_id"=>"", "place_id"=>"", "genre_id"=>"", "year"=>"1984",
      @f_artist_name=>artist2.title_or_alt, "year_engage"=>"", # Artist not accepted in #edit
      "engage_hows"=>["", engage_how1.id.to_s], # Artist not accepted in #edit
      "contribution"=>"",                       # Artist not accepted in #edit
      "note"=>""}
    hs = {}.merge hs_tmpl
    assert @music.place.covered_by? Country['JPN']
    assert_difference('Music.count*10 + Engage.count', 0) do
      #patch music_url(@music, params: { music: hs })
      patch music_url(@music, {params: { music: hs }}.merge(ApplicationController.new.default_url_options))
      assert_response :redirect
      assert_redirected_to music_url @music
    end

    @music.reload
    assert @music.place.covered_by? Country['AUS']
    assert_not_equal music_orig.place, @music.place

    # Update success with a significant place
    place_perth = places( :perth_aus )
    unknown_prefecture_aus = prefectures( :unknown_prefecture_aus )
    hs = hs_tmpl.merge({
       'place.prefecture_id' => unknown_prefecture_aus.id,
       'place_id' => place_perth.id,
       'genre_id' => genre_c.id.to_s,
       'year' => 1990,
    })
    assert_difference('Music.count*10 + Engage.count', 0) do
      patch music_url @music, params: { music: hs }
      assert_response :redirect
      assert_redirected_to music_url @music
    end

    @music.reload
    assert_equal 1990,        @music.year
    assert_equal place_perth, @music.place
    assert_equal genre_c,     @music.genre
    sign_out @editor
  end

  test "should get new" do
    get new_music_url
    sign_in @editor
    assert_response :redirect
    assert_redirected_to new_user_session_path

    get new_music_url
    assert_response :success
    w3c_validate "Music new"  # defined in test_helper.rb (see for debugging help)
    sign_out @editor
  end

  test "should show music" do
    assert((memoe=@music.memo_editor).strip.present?, "fixture testing")

    get music_url(@music)
    assert_response :success
    #refute css_select('div.link-edit-destroy a')[0].text.include? "Edit"
    w3c_validate "Music show"  # defined in test_helper.rb (see for debugging help)
    assert_equal 0, css_select("body dd.item_memo_editor").size, "should be Harami editor_only, but..."

    ## Artist table with another music
    mus = musics(:music_how)
    art = mus.artists.first
    assert (art_alt_tit = art.alt_title(langcode: "en")).present?, "fixture testing"
    get music_url(mus)
    cell = css_select('section#sec_artists_by table td.titles-en').first.text
    assert_includes cell, "["
    assert_match(/\s+\[#{Regexp.quote(art_alt_tit)}\]/m, cell.strip)

    ## Testing Artist table with @music (== :music1)
    ehow_cover = engage_hows(:engage_how_singer_cover)
    assert_equal 1, @music.engages.size                                 # testing fixture 
    music_ehow = @music.engages.first.engage_how
    assert_operator ehow_cover.weight, :<, music_ehow.weight  # testing fixture (the original associated EngageHow is lower in weight than new EngageHow-s)

    art2=artists(:artist2)
    art3=artists(:artist3)
    assert_equal "en", art2.orig_langcode.to_s  # testing fixture 
    assert_equal "ja", art3.orig_langcode.to_s  # testing fixture 

    eng2 = Engage.create!(music: @music, artist: art2, engage_how: ehow_cover, year: 2025, contribution: nil)
    eng3 = Engage.create!(music: @music, artist: art3, engage_how: ehow_cover, year: 2024, contribution: nil)
    assert_equal 3, @music.engages.reset.size                           # testing the setup

    get music_url(@music)
    assert_response :success
    basecsstxt = 'section#sec_artists_by table tr'
    css_rows = css_select(basecsstxt)
    all_ehows = css_select(basecsstxt + ' td.cell_engage_how').map(&:text).map(&:strip)
    assert_includes all_ehows[0], ehow_cover.title(langcode: "en")
    assert_includes all_ehows[1], ehow_cover.title(langcode: "en")
    assert_includes all_ehows[2], music_ehow.title(langcode: "en")
    assert_includes all_ehows[0], "2024", "The first entry should be the oldest one, but..."
    assert_includes all_ehows[1], "2025", "The second entry should be the second-oldest one, but..."
    assert_equal art2.title, css_select(basecsstxt + ' td.titles-en')[1].text.sub(/\s*\[.+/, "").strip
    assert_equal art3.title, css_select(basecsstxt + ' td.title-ja')[0].text.strip

    sign_in @editor
    abi = Ability.new(@editor)
    assert abi.can?(:update, Music)

    get music_url(@music)
    assert_equal 1, css_select("body dd.item_memo_editor").size
    assert_equal memoe, css_select("body dd.item_memo_editor").text.strip
    sign_out @editor
  end

  test "should get edit" do
    get edit_music_url(@music)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get edit_music_url(@music)
    assert_response :success

    w3c_validate "Music edit"  # defined in test_helper.rb (see for debugging help)

    assert css_select('a').any?{|i| /\AShow\b/ =~ i.text.strip}  # More fine-tuning for CSS-selector is needed!
    css = css_select('div.link-edit-destroy a')
    assert(css.empty? || !css[0].text.include?("Edit"))
    css = css_select('div.editor_only.memo_editor textarea')
    refute css.empty?

    sign_out @editor

    sign_in @moderator_all 
    get edit_music_url(@music)
    assert_response :success
    sign_out @moderator_all 
  end

  test "should destroy music if privileged" do
    music3 = musics(:music3)

    # Fail: No privilege
    assert_difference('Music.count', 0) do
      delete music_url(music3)
      assert_response :redirect
      assert_redirected_to new_user_session_path
    end

    sign_in @editor

    # Success: Successful deletion
    assert_difference('Music.count', -1) do
      assert_difference('Translation.count', -1) do
        assert_difference('HaramiVidMusicAssoc.count', -1) do
          assert_difference('Engage.count', -2) do # engage3_3 and engage3_4 deleted
            assert_difference('Artist.count', 0) do
              assert_difference('Place.count', 0) do
                delete music_url(music3)
              end
            end
          end
        end
      end
    end

    assert_response :redirect
    assert_redirected_to musics_url
    assert_raises(ActiveRecord::RecordNotFound){ music3.reload }
    sign_out @editor
  end
end
