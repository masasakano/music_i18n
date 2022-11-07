# coding: utf-8
require "test_helper"

class Artists::MergesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:artist_saki_kubota)
    @other  = artists(:artist_ai)
    @music1 = musics(:music_ihojin1)
    @music2 = musics(:music_ihojin2)
    @editor     = users(:user_editor_general_ja)  # (General) Editor can manage.
    @translator = users(:user_translator)
    @def_prm_artist = {
      other_artist_id: @other.id.to_s,
      to_index: '1',
      lang_orig: '1',
      lang_trans: nil,
      engage: '1',
      prefecture_place: '0',
      genre: '1',
      year: '0',
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get new" do
    assert_raise(ActionController::UrlGenerationError){
      get artists_new_merge_users_url  # ID must be given for this :new
    }

    # Fail: No privilege
    get artists_new_merge_users_url(@artist)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor

    get artists_new_merge_users_url(@artist)
    assert_response :success

    assert_match(/Other artist/i, css_select('form div.field label').text)
  end

  test "should get edit" do
    assert_raise(ActionController::UrlGenerationError){
      get artists_edit_merge_users_url  # ID must be given for this :edit
    }

    get artists_edit_merge_users_url(@artist)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    assert_raise(ActionController::ParameterMissing){
      get artists_edit_merge_users_url(@artist)
    } # This deactivates sign_in !!
    
    sign_in @editor
    get artists_edit_merge_users_url(@artist, params: {other_artist_id: @other.id})
    assert_response :success
 
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: @other.id}})
    assert_response :success
 
return  ################################################################################
    titnew = "異邦人でっしゃろ"
    mu2 = Artist.create_with_orig_translation!(note: 'MergesController-temp-creation', translation: {title: titnew, langcode: 'ja'})  # Create another Artist containing "異邦人" in the title
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "異邦人" }})
    assert_response :success
    flash_regex_assert(/found more than 1 Artist/i, type: :warning)
 
    strin = sprintf("%s   [%s] [%d] ", titnew, "ja", mu2.id)
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: titnew }})
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    strin = sprintf("%s   [%s] ", titnew, "ja")
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: titnew }})
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "こんな曲はきっとないことでしょう、どうするかな" }})
    assert_response :redirect
    follow_redirect!
    assert css_select('p.alert').text.include? 'No Artist matches'
  end

  test "should update1" do
    prm_artist = @def_prm_artist.merge({})
    #  other_artist_id: @other.id.to_s,
    #  to: '1',
    #  lang_orig: '1',
    #  lang_trans: nil,
    #  engage: '1'
    #  prefecture_place: '0',
    #  genre: '1',
    #  year: '0',
    # translations(:music_ihojin1_ja1) # weight:  0
    # translations(:music_ihojin1_en1) # weight: 10
    # translations(:music_ihojin1_en2) # weight: 100
    # translations(:music_ihojin1_en3) # weight: 17.5
    # translations(:music_ihojin2_ja1) # weight: 1
    # translations(:music_ihojin2_en1) # weight: 10
    # translations(:music_ihojin2_en2) # weight: 40
    # translations(:music_ihojin2_en3) # weight: 100
    # translations(:music_ihojin2_en4) # weight: 500

    artist_bkup = @artist.dup
    other_bkup = @other.dup
    refute @artist.destroyed?, 'sanity check-mu'
    refute @other.destroyed?, 'sanity check-ot'
    artist_hvma_last = @artist.harami_vid_artist_assocs.last
    assert_equal harami_vid_music_assocs(:harami_vid_music_assoc_3_ihojin1), artist_hvma_last # sanity check
    assert_equal @artist, artist_hvma_last.artist # 'sanity check-hvma'
    timing_hvma_bkup = artist_hvma_last.timing
    place_bkup0 = @artist.place
    genre_bkup1 = @other.genre
    year_bkup0  = @artist.year

    engage2delete = engages(:engage_kubota_ihojin1_1)  # will be delted because Composer-Kubota combination exists both 0 and 1 and Artist[1] has a priority.
    engage2change = engages(:engage_kubota_ihojin1_2)  # contribution will be nullified because Composer exist in Artist[1] which has a priority over this (Artist[0])
    engage2remain = engages(:engage_kubota_ihojin2_2)
    assert_equal engage2delete.artist, engage2remain.artist, 'sanity-check'
    assert_equal engage2delete.engage_how, engage2remain.engage_how, 'sanity-check'
    assert Harami1129.where(engage: engage2delete).exists?

    trans2delete  = translations(:music_ihojin1_ja1)
    trans2is_orig = translations(:music_ihojin2_ja1)
    assert trans2is_orig.is_orig
    trans2remain  = translations(:music_ihojin2_en1)
    trans2remain_weight = trans2remain.weight
    trans2change  = translations(:music_ihojin1_en1)
    trans2change_weight = trans2change.weight
    trans2change2 = translations(:music_ihojin1_en3)
    trans2change2_weight = trans2change2.weight
    assert_equal @artist.id, trans2change2.translatable_id, "sanity-check"

    patch place_url(@artist), params: { artist: prm_artist }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ### Trans (Moderator (10➝16;10*, 40), Editor1 (100→DEL,100), Editor2(12➝22,)) 

    sign_in @editor
    assert_difference('Artist.count', -1) do
      assert_difference('Translation.count', -3) do # ja(is_orig), "Alien woman", "Alien People" (duplications)
        assert_difference('HaramiVidMusicAssoc.count', 0) do
          assert_difference('Engage.count', -1) do # engage_kubota_ihojin1_1 deleted
            assert_difference('Artist.count', 0) do
              assert_difference('Place.count', 0) do
                patch artists_update_merge_users_url(@artist), params: { artist: prm_artist }
              end
            end
          end
        end
      end
    end
    assert_response :redirect
    assert_redirected_to artist_path(@other)

    refute Artist.exists?(@artist.id)  # refute @artist.destroyed?  ;;; does not work
    assert Artist.exists?(@other.id)
    @other.reload
return  ################################################################################

    # Translation is_orig=true
    refute Translation.exists?(trans2delete.id)
    assert Translation.exists?(trans2is_orig.id)
    assert_operator 0.6, :<, trans2is_orig.weight
    trans2is_orig.reload
    assert_operator 0.6, :>, trans2is_orig.weight

    # Translations
    trans2remain.reload
    assert_equal trans2remain_weight, trans2remain.weight
    trans2change.reload
    refute_equal trans2change_weight, trans2change.weight
    assert_equal 13, trans2change.weight, "Should be ((17.5-10)/2).to_i == 13, but...(#{trans2change.weight})"
    assert_equal @other.id, trans2change.translatable_id, "Associated Artist should have changed"
    trans2change2.reload
    assert_equal trans2change2_weight, trans2change2.weight
    assert_equal @other.id, trans2change2.translatable_id, "Associated Artist should have changed"

    # HaramiVidMusicAssoc
    artist_hvma_last.reload
    assert_equal @other, artist_hvma_last.artist  # Overwritten (harami_vid_music_assoc)
    assert_equal timing_hvma_bkup, artist_hvma_last.timing  # no change

    # Engage
    refute Engage.exists?(engage2delete.id)
    assert Engage.exists?(engage2remain.id)
    assert engage2change.contribution
    assert_equal @artist.id, engage2change.artist_id
    engage2change.reload
    assert_equal @other.id, engage2change.artist_id
    refute engage2change.contribution, 'Contribution should be nullified, because Composers exist in Artist[1] which has a priority over this (Artist[0]).'
    tmp_contri = engage2remain.contribution
    engage2remain.reload
    assert_equal tmp_contri, engage2remain.contribution

    # Place, Genre, year
    assert_equal place_bkup0, @other.place
    assert_equal genre_bkup1, @other.genre
    assert_equal  year_bkup0, @other.year

    # note
    str = other_bkup.note+" "+artist_bkup.note
    assert_equal str, @other.note
  end
end
