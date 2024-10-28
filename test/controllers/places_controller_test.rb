# coding: utf-8
require 'test_helper'
require_relative 'translation_common'

class PlacesControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::IntegrationTest::TranslationCommon # from translation_common.rb
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @place = places(:tocho)
    @editor    = roles(:general_ja_editor).users.first     # (General) Editor can manage.
    @moderator = roles(:general_ja_moderator).users.first  # (General) Moderator can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get places_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should get index" do
      get '/users/sign_in'
      sign_in Role[:editor, RoleCategory::MNAME_GENERAL_JA].users.first  # editor/general_ja
      post user_session_url
      follow_redirect!
      assert_response :success  # log-in successful

      get places_url
      assert_response :success

      refute_empty css_select("table.table_index_main tbody tr")
      assert css_select("table.table_index_main tbody tr").any?{|esel| esel.css('td.title_ja')[0].text.blank? && !esel.css('td.title_en')[0].text.blank?}, "Some JA titles should be blank (where EN titles are NOT blank), but..."
  end

  test "should get new only if logged in" do
    get new_place_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get new_place_url
    assert_response :success
  
    assert_equal 0, css_select(css_query(:trans_new, :is_orig_radio, model: Place)).size, "is_orig selection should not be provided, but..."  # defined in helpers/test_system_helper

    ## Specify a Prefecture
    country_id    = @place.prefecture.country_id
    prefecture_id = @place.prefecture_id
    get new_place_url(prefecture_id: prefecture_id) # e.g., new?prefecture_id=5
    assert_response :success

    csssel = css_select("select#place_prefecture\\.country_id option[value=#{country_id}]")
    assert_equal 'selected', csssel[0]['selected'], "CSS="+csssel[0].inspect

    csssel = css_select("select#place_prefecture optgroup[label=Japan] option[selected=selected]")
    assert_equal 1, csssel.size, "A Prefecture in Japan should be selected, but... csssel="+csssel.inspect

    csssel = css_select("select#place_prefecture option[value=#{prefecture_id}]")
    assert_equal 'selected', csssel[0]['selected'], "CSS="+csssel[0].inspect

    get new_place_url(place: {prefecture_id: prefecture_id}) # e.g., new?place[prefecture_id]=5
    assert_response :success
    assert_equal 'selected', csssel[0]['selected'], "CSS="+csssel[0].inspect
    assert_equal 'Prefecture',  css_select("input#place_prev_model_name")[0]["value"]
    assert_equal prefecture_id, css_select("input#place_prev_model_id")[0]["value"].to_i

    ## Specify a Country
    get new_place_url(country_id: country_id) # e.g., new?country_id=5
    assert_response :success

    csssel = css_select("select#place_prefecture\\.country_id option[value=#{country_id}]")
    assert_equal 'selected', csssel[0]['selected'], "CSS="+csssel[0].inspect

    csssel = css_select("select#place_prefecture option[selected=selected]")
    assert_empty  csssel, "No Prefecture should be selected, but... csssel="+csssel.inspect
  end

  test "should NOT create if not privileged" do
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefectures(:kagawa).id.to_s,
      "note"=>"test-create-place"}

    post places_url, params: { place: hs2pass }
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "should create" do
    note1 = "test-create-place"
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefectures(:kagawa).id.to_s,
      "note"=>note1}

    sign_in @editor

    # Creation success
    assert_difference('Place.count', 1) do
      post places_url, params: { place: hs2pass }
      assert_response :redirect #, "message is : "+flash.inspect
    end

    place = Place.order(:created_at).last
    assert_redirected_to place_url(place)
    assert_equal 'Test, The', place.title
    assert_equal 'en', place.orig_langcode
    assert place.covered_by? Country['JPN']
    assert place.covered_by?(prefectures(:kagawa)), "place #{place.inspect} should be covered by #{prefectures(:kagawa).inspect}"
    assert_equal note1, place.note

    # Creation fails because Prefecture is not specified.
    place = nil
    assert_difference('Place.count', 0) do
      post places_url, params: { place: hs2pass.merge({"title"=>"test2", "prefecture"=>""})}
      assert_response :unprocessable_entity #, "message is : "+flash.inspect
    end

    # Translation-related tests
    controller_trans_common(:place, hs2pass)  # defined in translation_common.rb
  end

  test "should create with the same name if Country is different" do
    note1 = "test-create-place"
    prefecture = prefectures(:kagawa)
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefecture.id.to_s,
      "note"=>note1,
      "prev_model_name"=>'Prefecture',  # suppose the prefecture value is already given.
      "prev_model_id"=>prefecture.id.to_s,
    }

    sign_in @editor

    # Creation success for a Place name that exists in a different country (or prefecture).
    # Tokyo[title, alt_title]: (ja)["東京都", nil], (en)["Tokyo", "Tôkyô"]
    assert_difference('Place.count') do
      assert_difference('Translation.count') do
        post places_url, params: { place: hs2pass.merge({"title" => places(:liverpool_street).title(langcode: 'en')}) }
        assert_response :redirect, sprintf("Expected response to be a <3XX: redirect>, but was <%s> with flash message: %s", response.code, flash.inspect)
      end
    end
    assert_redirected_to place_url(Place.last)
    #assert_redirected_to prefecture_url(prefecture)

    ## It displays Place#show, with a flash message containing a link to the original Prefecture
    follow_redirect!
    assert_response :success
    flash_regex_assert(/Prefecture \(<a.+>Kagawa\b<\/a>\)/, "Should be 'Prefecture: Kagawa', but...", type: :success, with_html: true) # defined in test_helper.rb

    css4flash = css_for_flash(:success, extra: "a") # defined in test_helper.rb
    assert_match(%r@\A/prefectures/#{prefecture.id}\b@, css_select(css4flash)[0]["href"], "Failed: Flash-success="+css_select(css4flash)[0].to_html)
    assert_match(/\AKagawa\z/, css_select(css4flash)[0].text)
  end

  test "should show place" do
    # show is NOT activated for non-logged-in user (or non-editor?).
    get place_url(@place)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get place_url(@place)
    assert_response :success
  end

  test "should fail/succeed to get edit" do
    get edit_place_url(@place)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get edit_place_url(@place)
    assert_response :success
  end

  test "should update place" do
    updated_at_orig = @place.updated_at
    pref_orig = @place.prefecture
    note2 = 'Edited new place note'
    patch place_url(@place), params: { place: { note: note2, prefecture_id: prefectures(:kagawa).id.to_s } }

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    patch place_url(@place), params: { place: { note: note2, prefecture_id: prefectures(:kagawa).id.to_s } }
    assert_response :redirect
    assert_redirected_to place_url(@place)

    @place.reload
    assert_operator updated_at_orig, :<, @place.updated_at
    assert_equal note2, @place.note
    assert_not_equal pref_orig, @place.prefecture
    assert_equal prefectures(:kagawa), @place.prefecture
  end

  test "even a moderator should fail to update an unknown place" do
    sign_in @moderator

    place1 = places(:unknown_place_tokyo_japan)
    note, updated_at = [place1.note, place1.updated_at]
    patch place_url(place1), params: { place: { note: "tekito" } }

    assert_response :redirect
    assert_redirected_to root_path
    place1.reload
    assert_equal note,      place1.note
    assert_equal updated_at, place1.updated_at
  end
  
  test "should fail/succeed to destroy place" do
    # Fail: No privilege
    assert_difference('Place.count', 0) do
      delete place_url(@place)
      assert_response :redirect
      assert_redirected_to new_user_session_path
    end

    # Fail: Cannot destroy Place because it has one or more dependent children of HaramiVid
    sign_in @editor
    assert_difference('Place.count', 0) do
      assert_difference('Translation.count', 0) do
        delete place_url(@place)
        #assert_response :unprocessable_entity
        assert_response :redirect
        assert_redirected_to places_path  # Because no current page is given.
      end
    end

    # Success: Successful deletion
    perth_aus = places(:perth_aus)
    assert_difference('Place.count', -1) do
      assert_difference('Translation.count', -1) do
        delete place_url(perth_aus)
      end
    end

    assert_response :redirect
    assert_redirected_to places_url
    assert_raises(ActiveRecord::RecordNotFound){ perth_aus.reload }
  end
end
