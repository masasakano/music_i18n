# coding: utf-8
require 'test_helper'
require_relative 'translation_common'

class PrefecturesControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::IntegrationTest::TranslationCommon # from translation_common.rb
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @prefecture = prefectures(:tokyo)
    @moderator = roles(:general_ja_moderator).users.first  # (General) Moderator can manage some of them.
    @editor = roles(:general_ja_editor).users.first  # (General) Editor can manage some of them.
    @syshelper = users(:user_syshelper) #User.roots.first   # an admin can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get prefectures_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should get index" do
    begin
      get '/users/sign_in'
      sign_in Role[:editor, RoleCategory::MNAME_GENERAL_JA].users.first  # editor/general_ja
      post user_session_url
      follow_redirect!
      assert_response :success  # log-in successful

      get prefectures_url
      assert_response :success
      get new_prefecture_url
      assert_response :success
      get prefecture_url(Prefecture.first)
      assert_response :success
    ensure
      Rails.cache.clear
    end
  end

  test "should fail to get new if not logged in but succeed if logged in" do
    get new_prefecture_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get new_prefecture_url
    assert_response :success
  
    w3c_validate "Prefecture new"  # defined in test_helper.rb (see for debugging help)

    assert_equal 0, css_select(css_query(:trans_new, :is_orig_radio, model: Prefecture)).size, "is_orig selection should not be provided, but..."  # defined in helpers/test_system_helper

    ## Specify a Country
    country_id = @prefecture.country_id
    get new_prefecture_url(country_id: country_id) # e.g., new?country_id=5
    assert_response :success

    csssel = css_select("select#prefecture_country_id option[selected=selected]")
    assert_equal 1, csssel.size, "A Country (Japan) should be selected, but... csssel="+csssel.inspect

    csssel = css_select("select#prefecture_country_id option[value=#{country_id}]")
    assert_equal 'selected', csssel[0]['selected'], "CSS="+csssel[0].inspect

    get new_prefecture_url(prefecture: {country_id: country_id}) # e.g., new?prefecture[country_id]=5
    assert_response :success
    assert_equal 'selected', csssel[0]['selected'], "CSS="+csssel[0].inspect
  end

  test "should create prefecture" do
    note1 = "test-create-prefecture"
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "country_id"=>countries(:uk).id.to_s,
      "note"=>note1}

    assert_no_difference('Prefecture.count') do
      #post prefectures_url, params: { prefecture: { country_id: Country['AUS'].id.to_s, note: note1 } }
      post prefectures_url, params: { prefecture: hs2pass }
      assert_response :redirect
      assert_redirected_to new_user_session_path
    end

    sign_in @editor

    # Creation success
    assert_difference('Prefecture.count') do
      post prefectures_url, params: { prefecture: hs2pass }
      assert_response :redirect #, "message is : "+flash.inspect
    end

    pref = Prefecture.order(:created_at).last # Prefecture.last
    assert_redirected_to prefecture_url(pref)
    title_test = 'Test, The'
    assert_equal title_test, pref.title
    assert_equal 'en', pref.orig_langcode
    assert pref.covered_by? countries(:uk)
    assert_equal note1, pref.note

    # Translation-related tests (duplication etc)
    controller_trans_common(:prefecture, hs2pass)  # defined in translation_common.rb
  end

  test "should create prefecture with an existing name in a different country" do
    note1 = "test-create-prefecture"
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "country_id"=>countries(:uk).id.to_s,
      "note"=>note1}

    sign_in @editor

    # Creation success for a Prefecture name that exists in a different country.
    # Tokyo[title, alt_title]: (ja)["東京都", nil], (en)["Tokyo", "Tôkyô"]
    assert_difference('Prefecture.count') do
      assert_difference('Place.count') do
        ntrans_unknown = Prefecture::UnknownPrefecture.size
        assert_difference('Translation.count', 1+ntrans_unknown) do  # 4 = 1 Trans(En) and 3 UnknownPlace-s(En,Ja,Fr)
          post prefectures_url, params: { prefecture: hs2pass.merge({"title" => prefectures(:tokyo).title(langcode: 'en')}) }
          assert_response :redirect, sprintf("Expected response to be a <3XX: redirect>, but was <%s> with flash message: %s", response.code, flash.inspect)
        end
      end
    end
  end

  test "should show prefecture" do
    # show is activated even for non-logged-in users.
    get prefecture_url(@prefecture)
    assert_response :success
  end

  test "should fail/succeed to get edit" do
    get edit_prefecture_url(@prefecture)
    assert_response :redirect
    assert_redirected_to new_user_session_path, "Should be redirected to Sign-in"

    sign_in @moderator
    get edit_prefecture_url(@prefecture)
    assert_response :redirect, "Even moderator should not be able to edit Prefectures in Japan"
    assert_redirected_to root_path, "Should be redirected Root"

    sign_in @editor
    get edit_prefecture_url(prefectures(:liverpool))
    assert_response :success, "Editor should be able to edit Prefectures in UK"

    sign_in @syshelper
    get edit_prefecture_url(@prefecture)
    assert_response :success, "Syshelper should be able to edit Prefectures in Japan"
  end

  test "should update prefecture if editor" do
    pref_liverpool = prefectures(:liverpool)

    updated_at_orig = pref_liverpool.updated_at
    country_orig = pref_liverpool.country
    note2 = 'Edited new prefecture note'
    patch prefecture_url(pref_liverpool), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s } }

    assert_response :redirect  # because not privileged
    assert_redirected_to new_user_session_path

    sign_in @editor
    patch prefecture_url(pref_liverpool), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s } }
    assert_response :redirect
    assert_redirected_to prefecture_url(pref_liverpool)

    pref_liverpool.reload
    assert_operator updated_at_orig, :<, pref_liverpool.updated_at
    assert_equal note2, pref_liverpool.note
    assert_not_equal country_orig, pref_liverpool.country
    assert_equal Country['AUS'], pref_liverpool.country
  end

  test "even a moderator should fail to update an unknown prefecture" do
    sign_in @moderator

    prefecture1 = prefectures(:unknown_prefecture_uk)
    note, updated_at = [prefecture1.note, prefecture1.updated_at]
    patch prefecture_url(prefecture1), params: { prefecture: { note: "tekito" } }

    assert_response :redirect
    assert_redirected_to root_path
    prefecture1.reload
    assert_equal note,      prefecture1.note
    assert_equal updated_at, prefecture1.updated_at
  end

  test "should update nothing for prefecture in Japan" do
    note2 = 'Edited new prefecture note'
    sign_in @moderator # Even moderator is not allowed to change parameters for prefectures in Japan.

    patch prefecture_url(@prefecture), params: { prefecture: { note: note2, iso3166_loc_code: 9998 } }
    assert_response :redirect, "Even moderator should not be able to edit Prefectures in Japan" # due to "ability"-level check
    assert_redirected_to root_path, "Should be redirected Root"

    patch prefecture_url(@prefecture), params: { prefecture: { country_id: Country['AUS'].id.to_s } }
    assert_response :redirect, "Even moderator should not be able to edit Prefectures in Japan" # due to "ability"-level check
    #assert_response :unprocessable_entity, "moderatora cannot change a JPN prefecure to another country"

    patch prefecture_url(@prefecture), params: { prefecture: { iso3166_loc_code: 9998 } }
    assert_response :redirect, "Even moderator should not be able to edit Prefectures in Japan" # due to "ability"-level check
    #assert_response :unprocessable_entity, "moderatora cannot change iso3166_loc_code of a JPN prefecure"

    patch prefecture_url(@prefecture), params: { prefecture: { note: note2 } }
    assert_response :redirect, "Even moderator should not be able to edit Prefectures in Japan" # due to "ability"-level check
    #assert_response :unprocessable_entity, "moderatora cannot change note of a JPN prefecure"

    pref_liverpool = prefectures(:liverpool)
    patch prefecture_url(pref_liverpool), params: { prefecture: { country_id: Country['JPN'].id.to_s } }
    assert_response :unprocessable_entity, "moderatora cannot change the country of a non-JPN prefecure to Japan" # due to Controller-level check (see _get_warning_msg())
  end

  test "syshelper should update for prefecture in Japan" do
    note2 = 'Edited new prefecture note'
    sign_in @syshelper # An admin is allowed to change parameters for prefectures in Japan.

    pref_orig = @prefecture.dup
    orig_updated_at1 = @prefecture.updated_at

    patch prefecture_url(@prefecture), params: { prefecture: { note: note2, country_id: Country['AUS'].id.to_s, iso3166_loc_code: 9998 } }
    assert_response :redirect
    assert_redirected_to prefecture_url(@prefecture)

    @prefecture.reload
    assert_operator orig_updated_at1, :<, @prefecture.updated_at
    assert_not_equal pref_orig.iso3166_loc_code, @prefecture.iso3166_loc_code
    assert_equal     9998,                       @prefecture.iso3166_loc_code
    assert_equal note2, @prefecture.note
    assert_not_equal pref_orig.country, @prefecture.country
    assert_equal Country['AUS'], @prefecture.country

    # warning should be printed as Country(Australia) is changed into Japan.
    follow_redirect!
    assert_response :success  # redirect success
    flash_regex_assert(/Prefecture was successfully updated\b/, "flash message should exist, but...", type: :success) # defined in test_helper.rb
    assert_equal 1, css_select(css_for_flash(:warning)).size # defined in test_helper.rb
    flash_regex_assert(/Make sure that is what you intended/, "flash warning message should exist, but...", type: :warning) # defined in test_helper.rb
    #assert_select 'div.alert-warning', text: "Make sure that is what you intended"  ## Exact match...

    orig_updated_at2 = @prefecture.updated_at
    patch prefecture_url(@prefecture), params: { prefecture: { note: "", country_id: Country['JPN'].id.to_s, iso3166_loc_code: pref_orig.iso3166_loc_code } }
    assert_response :redirect
    assert_redirected_to prefecture_url(@prefecture)

    @prefecture.reload
    assert_operator orig_updated_at2, :<, @prefecture.updated_at
    assert_equal pref_orig.iso3166_loc_code, @prefecture.iso3166_loc_code
    assert_equal pref_orig.country,          @prefecture.country
    assert_equal "",                         @prefecture.note
  end

  test "should destroy prefecture" do
    liverpool = prefectures(:liverpool)
    assert_equal 2, liverpool.places.size, 'Sanity check: Liverpool should have 2 Places including Place.unknown'
    assert_equal 1, liverpool.translations.size
    assert_equal 1, liverpool.places[0].translations.size

    assert_no_difference('Prefecture.count') do
      delete prefecture_url(liverpool)
      assert_response :redirect
    end

    sign_in @editor
    assert_difference('Prefecture.count', 0) do
      assert_no_difference('Translation.count') do
        delete prefecture_url(liverpool)
        assert_response :unprocessable_entity  #, "Prefecture with significant Places should not be destroyed"
        assert_equal URI.parse(prefecture_path(liverpool)).path, request.path
      end
    end

    assert_difference('Place.count', -1) do
      assert_difference('Translation.count', -1) do
        delete place_url(liverpool.places[-1])
        assert_response :redirect
        assert_redirected_to places_url
      end
    end
    assert_difference('Prefecture.count', -1) do
      assert_difference('Translation.count', -2, "Translations of Prefecture and Place.unknown should be destroyed") do
        delete prefecture_url(liverpool)
        assert_response :redirect #, "Prefecture with no significant Places should be destroyed"
        assert_redirected_to prefectures_url
      end
    end

    shimane = prefectures(:shimane)
    assert_equal 2, shimane.translations.size, 'Sanity check: shimane should have 1 translation'
    assert_equal 1, shimane.places.size, 'Sanity check: shimane should not have any significant Places but Place.unknown'

    sign_in @moderator
    assert_no_difference('Prefecture.count') do
      assert_no_difference('Translation.count') do
        delete prefecture_url(shimane)
        assert_response :redirect #, "Prefecture in Japan should not be destroyed by a moderator due to ability"
      end
    end

    sign_in @syshelper
    pla = Place.create!(prefecture_id: shimane.id, note: 'Test new place in Shimane')
    pla.with_orig_translation(title: 'NewShimanePlaceTestDestroy', langcode: 'en')
    assert_equal 2, shimane.places.size, 'Sanity check: shimane should have 1 significant Place and Place.unknown'

    assert_no_difference('Prefecture.count') do
      assert_no_difference('Translation.count') do
        delete prefecture_url(shimane)
        assert_response :unprocessable_entity #, "Prefecture with significant child Places should not be destroyed" # in Japan or elsewhere evey by an admin at the Controller level (though possible in the Model level; see models/prefecture.rb).
        assert_equal URI.parse(prefecture_path(shimane)).path, request.path
      end
    end

    # destroy the child Place first.
    assert_difference('Place.count', -1) do
      assert_difference('Translation.count', -1) do
        delete place_url(shimane.places[-1])
        assert_response :redirect
        assert_redirected_to places_url
      end
    end

    # Now the Prefecture has only Place.unknown. Hence an admin can destroy it, even though it is in Japan.
    assert_difference('Prefecture.count', -1) do
      assert_difference('Place.count', -1) do
        assert_difference('Translation.count', -3) do
          delete prefecture_url(shimane), params: { prefecture: { force_destroy: "1" } }
          assert_response :redirect #, "Prefecture should be forcibly destroyed by an admin"
          assert_redirected_to prefectures_url
        end
      end
    end
  end
end
