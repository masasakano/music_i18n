# coding: utf-8
require 'test_helper'

class PlacesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @place = places(:tocho)
    @editor = roles(:general_ja_editor).users.first  # (General) Editor can manage.
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
    begin
      get '/users/sign_in'
      sign_in Role[:editor, RoleCategory::MNAME_GENERAL_JA].users.first  # editor/general_ja
      post user_session_url
      follow_redirect!
      assert_response :success  # log-in successful

      get places_url
      assert_response :success
      get new_place_url
      assert_response :success
      get place_url(Place.first)
      assert_response :success
    ensure
      Rails.cache.clear
    end
  end

  test "should fail to get new if not logged in" do
    get new_place_url
    assert_response :redirect
    assert_redirected_to new_user_session_path
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
    hs2pass = {
      "langcode"=>"en",
      "title"=>"The Tｅst",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "prefecture.country_id"=>Country['JPN'].id.to_s,
      "prefecture"=>prefectures(:kagawa).id.to_s,
      "note"=>"test-create-place"}

    sign_in @editor

    # Creation success
    place = nil
    assert_difference('Place.count', 1) do
      post places_url, params: { place: hs2pass }
      assert_response :redirect #, "message is : "+flash.inspect
      place = Place.order(:created_at).last
      assert_redirected_to place_url(place)
    end

    assert_equal 'Test, The', place.title
    assert_equal 'en', place.orig_langcode
    assert place.covered_by? Country['JPN']
    assert place.covered_by?(prefectures(:kagawa)), "place #{place.inspect} should be covered by #{prefectures(:kagawa).inspect}"
    assert_equal "test-create-place", place.note

    # Creation fails because Prefecture is not specified.
    place = nil
    assert_difference('Place.count', 0) do
      post places_url, params: { place: hs2pass.merge({"prefecture"=>""})}
      assert_response :unprocessable_entity #, "message is : "+flash.inspect
    end

    # Creation fails because no Translation (or name) is specified.
    place = nil
    assert_difference('Place.count', 0) do
      post places_url, params: { place: hs2pass.merge({"title"=>""})}
      assert_response :unprocessable_entity #, "message is : "+flash.inspect
    end
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
