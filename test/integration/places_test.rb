# coding: utf-8
require "test_helper"

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class PlacesIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "can see the new page" do
    path = new_place_path(place: {country_id: countries(:aus).id})

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
    follow_redirect!
    assert_response :success

    #log_in_as( users(:user_sysadmin) )
    #sign_in( users(:user_sysadmin) )
    sign_in( users(:user_editor_general_ja) )
    get path
    assert_response :success
    
    # <input value="AI (ID=7)" disabled="disabled" type="text" name="place[artist_name]" id="place_artist_name">
    csssel = css_select('div#div_select_prefecture')
    assert_equal 1, csssel.css('label').size
    assert_match(/\APrefecture\z/, csssel.css('label').text.strip)
    assert_select "h1", 'New Place'
  end

  test "can create" do
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefectures(:kagawa).id.to_s,
      "note"=>"test-create-place",
    }

    sign_in( users(:user_editor_general_ja) )

    # Creation success
    place = nil
    assert_difference('Place.count', 1) do
      post places_url, params: { place: hs2pass }
      assert_response :redirect
    end

    assert_redirected_to place_path(Place.order(created_at: :desc).first.id)
    follow_redirect!
    assert_response :success
    # csssel = css_select('p.alert-success')
    assert_select ".alert-success", {count: 1, text: "Place was successfully created."}, "Wrong flash message or 0 or more than 1 flash-success"
  end

  test "can edit" do
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefectures(:kagawa).id.to_s,
      "note"=>"test-create-place",
    }

    tocho = places(:tocho)

    sign_in( users(:user_editor_general_ja) )
    get edit_place_url(tocho)
    assert_response :success
    assert_equal 'Japan', css_select('select[id="place_prefecture.country_id"] option[selected=selected]').text
    assert_equal 'Tôkyô', css_select('select#place_prefecture option[selected=selected]').text
  end

  test "can update" do
    hs2pass = {
      #"prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefectures(:kagawa).id.to_s,
      "note"=>"test-create-place",
    }
    note2 = 'Edited new place note'
    tocho = places(:tocho)
    tocho_id   = tocho.id
    pref_orig = tocho.prefecture

    sign_in( users(:user_editor_general_ja) )
    get edit_place_url(tocho)
    assert_difference('Place.count', 0) do
      patch place_url(tocho), params: { place: { note: note2, prefecture_id: prefectures(:kagawa).id.to_s } }
    end
    assert_response :redirect
    assert_redirected_to place_url(tocho)

    follow_redirect!
    assert_response :success
    # csssel = css_select('p.alert-success')
    assert_select ".alert-success", {count: 1, text: "Place was successfully updated."}, "Wrong flash message or 0 or more than 1 flash-success"

    tocho.reload
    assert_equal tocho_id, tocho.id
    assert_not_equal pref_orig,        tocho.prefecture
    assert_equal prefectures(:kagawa), tocho.prefecture
    assert_equal note2, tocho.note
  end

end
