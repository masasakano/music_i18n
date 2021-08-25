require 'test_helper'

class PlacesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @place = places(:tocho)
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

  #test "should get new" do
  #  get new_place_url
  #  assert_response :success
  #end

  #test "should create place" do
  #  assert_difference('Place.count') do
  #    post places_url, params: { place: { note: @place.note, prefecture_id: @place.prefecture_id } }
  #  end

  #  assert_redirected_to place_url(Place.last)
  #end

  #test "should show place" do
  #  get place_url(@place)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_place_url(@place)
  #  assert_response :success
  #end

  #test "should update place" do
  #  patch place_url(@place), params: { place: { note: @place.note, prefecture_id: @place.prefecture_id } }
  #  assert_redirected_to place_url(@place)
  #end

  #test "should destroy place" do
  #  assert_difference('Place.count', -1) do
  #    delete place_url(@place)
  #  end

  #  assert_redirected_to places_url
  #end
end
