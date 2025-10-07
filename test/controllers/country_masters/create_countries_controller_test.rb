# coding: utf-8
require "test_helper"

class CountryMasters::CreateCountriesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @country_master = country_masters(:syria_master)
    @moderator = users(:user_moderator_general_ja)  # (General) Editor can manage.
    @editor = users(:user_editor_general_ja)  # (General) Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should not post update if logged in as an editor" do
    post country_masters_create_countries_path(@country_master.id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    assert_no_difference("Country.count") do
      post country_masters_create_countries_path(@country_master.id)
      assert_response :redirect
    end
    assert_redirected_to root_path
    sign_out @editor
  end

  test "should not post update if logged in as a moderator" do
    sign_in @moderator
    assert_raises(ActiveRecord::RecordNotFound){
      post country_masters_create_countries_path(CountryMaster.order(:id).last.id+1)}

    ability = Ability.new(@moderator)
    assert ability.can?(:update, CountryMasters::CreateCountriesController)

    sign_in @moderator  # required because the user has been forcibly signed out!

    assert_difference("Country.count") do
      post country_masters_create_countries_path(@country_master.id)
      assert_response :redirect
    end

    cntry_new = Country.last
    assert_redirected_to cntry_new

    assert_equal @country_master.iso3166_a2_code, cntry_new.iso3166_a2_code
    assert_equal @country_master.name_ja_full,    cntry_new.best_translations["ja"].title, "Trans: "+cntry_new.best_translations["ja"].inspect
    follow_redirect!
    flash_regex_assert(/successfully created/, msg="CountryMaster to Country...")

    assert_no_difference("Country.count") do
      post country_masters_create_countries_path(@country_master.id)
      assert_response :redirect
      #assert_response :unprocessable_content
    end
    assert_redirected_to @country_master
    follow_redirect!
    ## puts @response.parsed_body

    flash_regex_assert(/child Country already exists/, msg="CountryMaster to Country...")

  end

end
