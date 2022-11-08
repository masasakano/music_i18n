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
      sex: '1',
      birthday: '0',
      wiki_en: '1',
      wiki_ja: '0',
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

    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_title: "久保田" }})
    assert_response :redirect
    assert_redirected_to artists_new_merge_users_url(@artist)
    follow_redirect!
    flash_regex_assert(/No Artist match/i, type: :alert) # because the current Artist is excluded.
 
    asex = Sex.first
    titnew = "久保田違う人だよ"
    mu2 = Artist.create_with_orig_translation!({sex: asex, note: 'MergesController-temp-creation'}, translation: {title: titnew, langcode: 'ja'})  # Create another Artist containing "久保田" in the title
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "久保田" }})
    assert_response :success

    titnew3 = "久保だけ一緒の人"
    mu3 = Artist.create_with_orig_translation!({sex: asex, note: 'MergesController-temp-creation'}, translation: {title: titnew3, langcode: 'ja'})  # Create another Artist containing "久保田" in the title
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "久保" }})
    assert_response :success
    flash_regex_assert(/found more than 1 Artist/i, type: :warning)
 
    strin = sprintf("%s   [%s] [%d] ", titnew, "ja", mu2.id)
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: titnew }})
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    strin = sprintf("%s   [%s] ", titnew, "ja")
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "久保田" }}) # there should be two 久保田s and one of them is the ID, hence there should be only 1 (== mu2).
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    get artists_edit_merge_users_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "こんな曲はきっとないことでしょう、どうするかな" }})
    assert_response :redirect
    follow_redirect!
    assert css_select('p.alert').text.include? 'No Artist matches'
  end

  ## @artist is merged into @other
  test "should update1" do
    prm_artist = @def_prm_artist.merge({})
    #  other_artist_id: @other.id.to_s,
    #  to: '1',            # => @other
    #  lang_orig: '1',        # => @other
    #  lang_trans: nil,       # => @other
    #  engage: '1'            # => @other
    #  prefecture_place: '0', # => @artist
    #  sex: '1',
    #  birthday: '0',
    #  wiki_en: '1',
    #  wiki_ja: '0',

    @artist.update!(created_at: DateTime.new(1))  # very old creation.
    @artist.update!(wiki_en: "abc", wiki_ja: '日本00')
    @other.update!( wiki_en: nil,   wiki_ja: '日本other')  # testing nil (so, the other one is adopted)
    @artist.update!(birth_year:  nil, birth_month: 9, birth_day: nil) # this will be chosen b/c at least one of them is non-nil.
    @other.update!( birth_year: 1990, birth_month: 2, birth_day: 3)
    @other.update!( wiki_en: nil,   wiki_ja: '日本other')  # testing nil (so, the other one is adopted)
    artist_bkup = @artist.dup
    other_bkup = @other.dup
    refute @artist.destroyed?, 'sanity check-artist-kubota'
    refute @other.destroyed?, 'sanity check-other'
    
    hvma_bkup = harami_vid_music_assocs(:harami_vid_music_assoc_3_ihojin1)
    assert  hvma_bkup.music.artists.include?(@artist), 'sanity-check'
    place_bkup0 = @artist.place
    sex_bkup1   = @other.sex
    birthday_bkup0 = [@artist.birth_year, @artist.birth_month, @artist.birth_day]
    wikien_bkup1   = @artist.wiki_en  # because @other.wiki_en.nil?
    wikija_bkup1   = @artist.wiki_ja

    # These tests do not cover many potentials, to be honest!
    engage2change11 = engages(:engage_kubota_ihojin1_1) # changed to belong to AI (no change in other parameters)
    engage2change13 = engages(:engage_kubota_ihojin1_3) # changed to belong to AI (no change in other parameters)
    engage2change22 = engages(:engage_kubota_ihojin2_2) # changed to belong to AI (no change in other parameters)
    assert_equal @artist, engage2change11.artist, 'sanity-check'
    assert_equal engage2change13.artist, engage2change22.artist, 'sanity-check'

    trans2delete1 = translations(:artist_saki_kubota_ja)
    assert trans2delete1.is_orig, 'sanity-check: because of is_orit=true, this will be deleted.'
    trans2remain1 = translations(:artist_saki_kubota_en1)
    trans2remain2 = translations(:artist_saki_kubota_en2)
    assert_operator 2, :<, @artist.translations.count, 'sanity-check of fixtures' # should be 3 so far.
    assert_equal @artist, trans2delete1.translatable, 'sanity-check'
    assert_equal trans2delete1.translatable_id, trans2remain2.translatable_id, 'sanity-check'

    patch artists_update_merge_users_url(@artist), params: { artist: prm_artist }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ### Trans (Moderator (10➝16;10*, 40), Editor1 (100→DEL,100), Editor2(12➝22,)) 

    sign_in @editor
    assert_difference('Artist.count', -1) do
      assert_difference('Translation.count', -1) do # 
        assert_difference('HaramiVidMusicAssoc.count', 0) do
          assert_difference('Engage.count', 0) do
            assert_difference('Music.count', 0) do
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

    # created_at is adjusted to the older one.
    assert_equal @artist.created_at, @other.created_at

    # Translations deleted/remain
    refute Translation.exists?(trans2delete1.id)
    assert Translation.exists?(trans2remain1.id)
    assert Translation.exists?(trans2remain2.id)

    # Translations
    user_assert_updated?(trans2remain1)  # defined in test_helper.rb
    user_assert_updated?(trans2remain2)  # defined in test_helper.rb

    # HaramiVidMusicAssoc
    user_refute_updated?(hvma_bkup, 'HaramiVidMusicAssoc should not change')  # defined in test_helper.rb

    # Engage
    assert Engage.exists?(engage2change11.id)
    assert Engage.exists?(engage2change13.id)
    assert Engage.exists?(engage2change22.id)
    cont_old = engage2change11.contribution
    [engage2change11, engage2change13,  engage2change22]. each do |i|
      user_assert_updated_attr?(i, :artist)  # defined in test_helper.rb
    end
    assert_equal @other,   engage2change11.artist  # it was just reloaded in the method above.
    assert_equal cont_old, engage2change11.contribution  # no change

    # Place, Sex, birthday
    assert_equal place_bkup0, @other.place
    assert_equal sex_bkup1, @other.sex
    assert_equal birthday_bkup0, [@other.birth_year, @other.birth_month, @other.birth_day]
    assert_equal wikien_bkup1, @other.wiki_en
    assert_equal wikija_bkup1, @other.wiki_ja

    # note
    str = other_bkup.note+" "+artist_bkup.note
    assert_equal str, @other.note
  end
end
