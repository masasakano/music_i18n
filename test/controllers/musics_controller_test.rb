# coding: utf-8
require 'test_helper'

class MusicsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @music = musics(:music1)
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
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
  end

  test "should create" do
    sign_in @editor

    artist_ai = artists( :artist_ai )
    engage_how_composer = engage_hows( :engage_how_composer )
    engage_how_player   = engage_hows( :engage_how_player   )

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
      "note"=>""}

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
    assert_equal @editor, music.translations.first.create_user, "(NOTE: for some reason, created_user_id is nil) User=#{@editor.inspect} Translation(=music.translations.first)="+music.translations.first.inspect

    # Failure due to non-existent Artist
    assert_difference('Music.count', 0) do
      post musics_url, params: { music: hstmpl.merge({@f_artist_name=>'naiyo'}) }
      assert_response :success
    end
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
  end

  test "should get new" do
    get new_music_url
    sign_in @editor
    assert_response :redirect
    assert_redirected_to new_user_session_path

    get new_music_url
    assert_response :success
    w3c_validate "Music new"  # defined in test_helper.rb (see for debugging help)
  end

  test "should show music" do
    get music_url(@music)
    assert_response :success
    #refute css_select('div.link-edit-destroy a')[0].text.include? "Edit"
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

    sign_out @editor

    sign_in @moderator_all 
    get edit_music_url(@music)
    assert_response :success
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
  end
end
