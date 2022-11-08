# coding: utf-8
require "test_helper"

class Musics::MergesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @music = musics(:music_ihojin1)
    @other = musics(:music_ihojin2)
    @editor     = users(:user_editor_general_ja)  # (General) Editor can manage.
    @translator = users(:user_translator)
    @def_prm_music = {
      other_music_id: @other.id.to_s,
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
      get musics_new_merges_url  # ID must be given for this :new
    }

    # Fail: No privilege
    get musics_new_merges_url(@music)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor

    get musics_new_merges_url(@music)
    assert_response :success

    assert_match(/Other music/i, css_select('form div.field label').text)
  end

  test "should get edit" do
    assert_raise(ActionController::UrlGenerationError){
      get musics_edit_merges_url  # ID must be given for this :edit
    }

    get musics_edit_merges_url(@music)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    assert_raise(ActionController::ParameterMissing){
      get musics_edit_merges_url(@music)
    } # This deactivates sign_in !!
    
    sign_in @editor
    get musics_edit_merges_url(@music, params: {other_music_id: musics(:music_ihojin1).id})
    assert_response :success
 
    get musics_edit_merges_url(@music, params: {music: {other_music_id: musics(:music_ihojin1).id}})
    assert_response :success
 
    titnew = "異邦人でっしゃろ"
    mu2 = Music.create_with_orig_translation!(note: 'MergesController-temp-creation', translation: {title: titnew, langcode: 'ja'})  # Create another Music containing "異邦人" in the title
    get musics_edit_merges_url(@music, params: {music: {other_music_id: nil, other_music_title: "異邦人" }})
    assert_response :success
    flash_regex_assert(/found more than 1 Music/i, type: :warning)
 
    strin = sprintf("%s   [%s] [%d] ", titnew, "ja", mu2.id)
    get musics_edit_merges_url(@music, params: {music: {other_music_id: nil, other_music_title: titnew }})
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    strin = sprintf("%s   [%s] ", titnew, "ja")
    get musics_edit_merges_url(@music, params: {music: {other_music_id: nil, other_music_title: titnew }})
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    get musics_edit_merges_url(@music, params: {music: {other_music_id: nil, other_music_title: "こんな曲はきっとないことでしょう、どうするかな" }})
    assert_response :redirect
    follow_redirect!
    assert css_select('p.alert').text.include? 'No Music matches'
  end

  ## @music is merged into @other
  test "should update1" do
    prm_music = @def_prm_music.merge({})
    #  other_music_id: @other.id.to_s,
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

    @music.update!(created_at: DateTime.new(1))  # very old creation.
    music_bkup = @music.dup
    other_bkup = @other.dup
    refute @music.destroyed?, 'sanity check-mu'
    refute @other.destroyed?, 'sanity check-ot'
    music_hvma_last = @music.harami_vid_music_assocs.last
    assert_equal harami_vid_music_assocs(:harami_vid_music_assoc_3_ihojin1), music_hvma_last # sanity check
    assert_equal @music, music_hvma_last.music # 'sanity check-hvma'
    timing_hvma_bkup = music_hvma_last.timing
    place_bkup0 = @music.place
    genre_bkup1 = @other.genre
    year_bkup0  = @music.year

    engage2delete = engages(:engage_kubota_ihojin1_1)  # will be delted because Composer-Kubota combination exists both 0 and 1 and Music[1] has a priority.
    engage2change = engages(:engage_kubota_ihojin1_2)  # contribution will be nullified because Composer exist in Music[1] which has a priority over this (Music[0])
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
    assert_equal @music.id, trans2change2.translatable_id, "sanity-check"

    patch musics_update_merges_url(@music), params: { music: prm_music }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ### Trans (Moderator (10➝16;10*, 40), Editor1 (100→DEL,100), Editor2(12➝22,)) 

    sign_in @editor
    assert_difference('Music.count', -1) do
      assert_difference('Translation.count', -3) do # ja(is_orig), "Alien woman", "Alien People" (duplications)
        assert_difference('HaramiVidMusicAssoc.count', 0) do
          assert_difference('Engage.count', -1) do # engage_kubota_ihojin1_1 deleted
            assert_difference('Artist.count', 0) do
              assert_difference('Place.count', 0) do
                patch musics_update_merges_url(@music), params: { music: prm_music }
              end
            end
          end
        end
      end
    end
    assert_response :redirect
    assert_redirected_to music_path(@other)

    refute Music.exists?(@music.id)  # refute @music.destroyed?  ;;; does not work
    assert Music.exists?(@other.id)
    @other.reload

    # created_at is adjusted to the older one.
    assert_equal @music.created_at, @other.created_at

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
    assert_equal @other.id, trans2change.translatable_id, "Associated Music should have changed"
    trans2change2.reload
    assert_equal trans2change2_weight, trans2change2.weight
    assert_equal @other.id, trans2change2.translatable_id, "Associated Music should have changed"

    # HaramiVidMusicAssoc
    music_hvma_last.reload
    assert_equal @other, music_hvma_last.music  # Overwritten (harami_vid_music_assoc)
    assert_equal timing_hvma_bkup, music_hvma_last.timing  # no change

    # Engage
    refute Engage.exists?(engage2delete.id)
    assert Engage.exists?(engage2remain.id)
    assert engage2change.contribution
    assert_equal @music.id, engage2change.music_id
    engage2change.reload
    assert_equal @other.id, engage2change.music_id
    refute engage2change.contribution, 'Contribution should be nullified, because Composers exist in Music[1] which has a priority over this (Music[0]).'
    tmp_contri = engage2remain.contribution
    engage2remain.reload
    assert_equal tmp_contri, engage2remain.contribution

    # Place, Genre, year
    assert_equal place_bkup0, @other.place
    assert_equal genre_bkup1, @other.genre
    assert_equal  year_bkup0, @other.year

    # note
    str = other_bkup.note+" "+music_bkup.note
    assert_equal str, @other.note
  end
end
