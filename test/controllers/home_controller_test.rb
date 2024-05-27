# coding: utf-8
require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get home_index_url
    assert_response :success
    w3c_validate "Home index"  # defined in test_helper.rb (see for debugging help)

    # this is not perfect because sometimes both JA and EN can be null because fixtures are not perfectly set...
    # See the index test in harami_vids_controller_test.rb for a better one, where fields with both JA and EN blank are excluded.
    assert css_select("table#home_table_main td.music_title_ja").any?{|i| /&mdash;|—/ !~ i.to_html}, "Some JA titles should be blank, but..."  # see method: view_home_music(langcode) / Note: because it is testing, some JA titles may not exist, whereas EN titles usually exist.
  end

  test "user with roles should get index" do
    user = roles(:general_ja_editor).users.first  # an Editor
    sign_in user
    get home_index_url
    assert_response :success
    sign_out user

    user = roles(:general_ja_moderator).users.first  # a Moderator
    sign_in user
    get home_index_url
    assert_response :success
    sign_out user

    user = users(:user_sysadmin)
    sign_in user
    get home_index_url
    assert_response :success
    sign_out user
  end

end
