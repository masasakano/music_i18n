require 'test_helper'

class CountriesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @country = countries(:japan)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get countries_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    get new_country_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should get index" do
    begin
      get '/users/sign_in'
      sign_in Role[:moderator, RoleCategory::MNAME_GENERAL_JA].users.first   # moderator/general_ja
      post user_session_url

      # If you want to test that things are working correctly, uncomment this below:
      follow_redirect!
      assert_response :success
      get countries_url
      assert_response :success
      get new_country_url
      assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
      get country_url(Country.first)
      assert_response :success
    ensure
      Rails.cache.clear
    end
  end

  #test "should get new" do
  #  get new_country_url
  #  assert_response :success
  #end

  #test "should create country" do
  #  assert_difference('Country.count') do
  #    post countries_url, params: { country: { note: @country.note } }
  #  end

  #  assert_redirected_to country_url(Country.last)
  #end

  #test "should show country" do
  #  get country_url(@country)
  #  assert_response :success
  #end

  #test "should get edit" do
  #  get edit_country_url(@country)
  #  assert_response :success
  #end

  #test "should update country" do
  #  patch country_url(@country), params: { country: { note: @country.note } }
  #  assert_redirected_to country_url(@country)
  #end

  #test "should destroy country" do
  #  assert_difference('Country.count', -1) do
  #    delete country_url(@country)
  #  end

  #  assert_redirected_to countries_url
  #end
end
