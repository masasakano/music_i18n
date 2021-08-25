require "test_helper"

class CountryMastersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @country_master = country_masters(:aus_master)
    @moderator = roles(:general_ja_moderator).users.first  # Moderator can read
    @editor = roles(:general_ja_editor).users.first  # Moderator can read
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    get country_masters_url
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route

    sign_in @editor 
    get country_masters_url
    assert_response :redirect

    sign_in @moderator
    get country_masters_url
    assert_response :success
  end

  test "should fail to get new" do
    sign_in @moderator
    get new_country_master_url
    assert_response :redirect
  end

  test "should fail to create country_master" do
    sign_in @moderator
    assert_difference('CountryMaster.count', 0) do
      post country_masters_url, params: { country_master: { iso3166_a2_code: @country_master.iso3166_a2_code.sub(/^./,'X'), iso3166_a3_code: @country_master.iso3166_a3_code.sub(/^./,'X'), iso3166_n3_code: @country_master.iso3166_n3_code+1000, name_ja_full: 'dummy999', } }
    end
    #assert_redirected_to country_master_url(CountryMaster.last)
  end

  test "should show country_master" do
    sign_in @editor 
    get country_master_url(@country_master)
    assert_response :redirect

    sign_in @moderator
    get country_master_url(@country_master)
    assert_response :success
  end

  test "should fail to get edit" do
    sign_in @moderator
    get edit_country_master_url(@country_master)
    assert_response :redirect
    assert_redirected_to root_url
  end

  test "should fail to update country_master" do
    sign_in @moderator
    a2 = @country_master.iso3166_a2_code
    patch country_master_url(@country_master), params: { country_master: { iso3166_a2_code: @country_master.iso3166_a2_code.sub(/^./,'X'), iso3166_a3_code: @country_master.iso3166_a3_code.sub(/^./,'X'), iso3166_n3_code: @country_master.iso3166_n3_code+1000, name_ja_full: 'dummy999', } }

    @country_master.reload
    assert_equal a2, @country_master.iso3166_a2_code
    assert_redirected_to root_url
    #assert_redirected_to country_master_url(@country_master)
  end

  test "should fail to destroy country_master" do
    sign_in @moderator
    assert_difference('CountryMaster.count', 0) do
      delete country_master_url(@country_master)
    end

    assert_redirected_to root_url
    #assert_redirected_to country_masters_url
  end
end
