# coding: utf-8
require "test_helper"

class PlayRolesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @play_role = play_roles(:play_role_inst_player_main)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    #@validator = W3CValidators::NuValidator.new
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get play_roles_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator_harami
    get play_roles_url
    assert_response :success
  end

  test "should get new" do
    sign_in @moderator_harami
    get new_play_role_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @syshelper
    get new_play_role_url
    assert_response :success
  end

  test "should create play_role" do
    assert_no_difference("PlayRole.count") do
      post play_roles_url, params: { play_role: { mname: "naiyo1", note: "", weight: 54 } }
    end

    sign_in @moderator_harami
    assert_no_difference("PlayRole.count") do
      post play_roles_url, params: { play_role: { mname: "naiyo1", note: "", weight: 54 } }
    end
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @syshelper
    assert_difference("PlayRole.count") do
      post play_roles_url, params: { play_role: { mname: "naiyo1", note: "", weight: 54 } }
    end
    eeih_last = PlayRole.last
    assert_redirected_to play_role_url(eeih_last)
    assert_equal 54, eeih_last.weight

    assert_no_difference("PlayRole.count") do
      post play_roles_url, params: { play_role: { mname: "naiyo1", note: "", weight: 12345 } }
    end
    assert_response :unprocessable_entity
  end

  test "should show play_role" do
    get play_role_url(@play_role)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get play_role_url(@play_role)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get play_role_url(@play_role)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    sign_in @moderator_harami
    get play_role_url(@play_role)
    assert_response :success
  end

  test "should get edit" do
    sign_in @moderator_harami
    get edit_play_role_url(@play_role)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @sysadmin
    get edit_play_role_url(@play_role)
    assert_response :success
  end

  test "should update play_role" do
    patch play_role_url(@play_role), params: { play_role: { mname: @play_role.mname, note: @play_role.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator_harami
    patch play_role_url(@play_role), params: { play_role: { mname: @play_role.mname, note: @play_role.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @syshelper
    patch play_role_url(@play_role), params: { play_role: { mname: @play_role.mname, note: @play_role.note, weight: 91 } }
    assert_redirected_to play_role_url(@play_role)
    assert_equal 91, @play_role.reload.weight

    assert_redirected_to play_role_url(@play_role)
  end

  test "should destroy play_role" do
    sign_in @syshelper
    assert_no_difference("PlayRole.count") do
      delete play_role_url(@play_role)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @syshelper

    sign_in @sysadmin
    assert_difference("PlayRole.count", -1) do
      delete play_role_url(@play_role)
      assert_response :redirect
    end
    assert_redirected_to play_roles_url
  end
end
