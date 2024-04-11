# coding: utf-8
require "test_helper"

class EngageEventItemHowsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @engage_event_item_how = engage_event_item_hows(:engage_event_item_how_inst_player_main)
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
    get engage_event_item_hows_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator_harami
    get engage_event_item_hows_url
    assert_response :success
  end

  test "should get new" do
    sign_in @moderator_harami
    get new_engage_event_item_how_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @syshelper
    get new_engage_event_item_how_url
    assert_response :success
  end

  test "should create engage_event_item_how" do
    assert_no_difference("EngageEventItemHow.count") do
      post engage_event_item_hows_url, params: { engage_event_item_how: { mname: "naiyo1", note: "", weight: 54 } }
    end

    sign_in @moderator_harami
    assert_no_difference("EngageEventItemHow.count") do
      post engage_event_item_hows_url, params: { engage_event_item_how: { mname: "naiyo1", note: "", weight: 54 } }
    end
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @syshelper
    assert_difference("EngageEventItemHow.count") do
      post engage_event_item_hows_url, params: { engage_event_item_how: { mname: "naiyo1", note: "", weight: 54 } }
    end
    eeih_last = EngageEventItemHow.last
    assert_redirected_to engage_event_item_how_url(eeih_last)
    assert_equal 54, eeih_last.weight

    assert_no_difference("EngageEventItemHow.count") do
      post engage_event_item_hows_url, params: { engage_event_item_how: { mname: "naiyo1", note: "", weight: 12345 } }
    end
    assert_response :unprocessable_entity
  end

  test "should show engage_event_item_how" do
    get engage_event_item_how_url(@engage_event_item_how)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get engage_event_item_how_url(@engage_event_item_how)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get engage_event_item_how_url(@engage_event_item_how)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    sign_in @moderator_harami
    get engage_event_item_how_url(@engage_event_item_how)
    assert_response :success
  end

  test "should get edit" do
    sign_in @moderator_harami
    get edit_engage_event_item_how_url(@engage_event_item_how)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @sysadmin
    get edit_engage_event_item_how_url(@engage_event_item_how)
    assert_response :success
  end

  test "should update engage_event_item_how" do
    patch engage_event_item_how_url(@engage_event_item_how), params: { engage_event_item_how: { mname: @engage_event_item_how.mname, note: @engage_event_item_how.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator_harami
    patch engage_event_item_how_url(@engage_event_item_how), params: { engage_event_item_how: { mname: @engage_event_item_how.mname, note: @engage_event_item_how.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @syshelper
    patch engage_event_item_how_url(@engage_event_item_how), params: { engage_event_item_how: { mname: @engage_event_item_how.mname, note: @engage_event_item_how.note, weight: 91 } }
    assert_redirected_to engage_event_item_how_url(@engage_event_item_how)
    assert_equal 91, @engage_event_item_how.reload.weight

    assert_redirected_to engage_event_item_how_url(@engage_event_item_how)
  end

  test "should destroy engage_event_item_how" do
    sign_in @syshelper
    assert_no_difference("EngageEventItemHow.count") do
      delete engage_event_item_how_url(@engage_event_item_how)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @syshelper

    sign_in @sysadmin
    assert_difference("EngageEventItemHow.count", -1) do
      delete engage_event_item_how_url(@engage_event_item_how)
      assert_response :redirect
    end
    assert_redirected_to engage_event_item_hows_url
  end
end
