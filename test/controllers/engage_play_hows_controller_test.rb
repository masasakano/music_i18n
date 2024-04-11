# coding: utf-8
require "test_helper"

class EngagePlayHowsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @engage_play_how = engage_play_hows(:engage_play_how_piano)
    #@engage_event_item_how = engage_event_item_hows(:engage_event_item_how_inst_player_main)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    #@validator = W3CValidators::NuValidator.new
    @hs_create_lang = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get engage_play_hows_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator_harami
    get engage_play_hows_url
    assert_response :success
  end

  test "should get new" do
    sign_in @editor_harami
    refute @editor_harami.moderator?
    refute Ability.new(@editor_harami).can?(:read, EngagePlayHow)
    get new_engage_play_how_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @moderator_harami
    #sign_in @syshelper
    get new_engage_play_how_url
    assert_response :success
  end

  test "should create engage_play_how" do
    hs2pass = @hs_create_lang.merge({ note: "", weight: 54 })
    assert_no_difference("EngagePlayHow.count") do
      post engage_play_hows_url, params: { engage_play_how: hs2pass }
    end

    [@editor_harami, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("EngagePlayHow.count") do
        post engage_play_hows_url, params: { engage_play_how: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @moderator_harami
    #sign_in @syshelper
    assert_difference("EngagePlayHow.count") do
      post engage_play_hows_url, params: { engage_play_how: hs2pass }
    end
    eeih_last = EngagePlayHow.last
    assert_redirected_to engage_play_how_url(eeih_last)
    assert_equal 54, eeih_last.weight

    assert_no_difference("EngagePlayHow.count") do
      post engage_play_hows_url, params: { engage_play_how: { note: "", weight: 12345 } }
    end
    assert_response :unprocessable_entity
  end

  test "should show engage_play_how" do
    get engage_play_how_url(@engage_play_how)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get engage_play_how_url(@engage_play_how)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get engage_play_how_url(@engage_play_how)
    assert_response :success, "Any moderator should be able to read, but..."
  end

  test "should get edit" do
    sign_in @editor_harami
    get edit_engage_play_how_url(@engage_play_how)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @moderator_harami
    #sign_in @sysadmin
    get edit_engage_play_how_url(@engage_play_how)
    assert_response :success
  end

  test "should update engage_play_how" do
    patch engage_play_how_url(@engage_play_how), params: { engage_play_how: { note: @engage_play_how.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @trans_moderator
    patch engage_play_how_url(@engage_play_how), params: { engage_play_how: { note: @engage_play_how.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    sign_in @moderator_harami
    patch engage_play_how_url(@engage_play_how), params: { engage_play_how: { note: @engage_play_how.note, weight: 91 } }
    assert_redirected_to engage_play_how_url(@engage_play_how)
    assert_equal 91, @engage_play_how.reload.weight

    assert_redirected_to engage_play_how_url(@engage_play_how)
  end

  test "should destroy engage_play_how" do
    sign_in @trans_moderator 
    assert_no_difference("EngagePlayHow.count") do
      delete engage_play_how_url(@engage_play_how)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @trans_moderator

    sign_in @moderator_harami
    #sign_in @syshelper
    assert_difference("EngagePlayHow.count", -1) do
      delete engage_play_how_url(@engage_play_how)
      assert_response :redirect
    end
    assert_redirected_to engage_play_hows_url

    assert_no_difference("EngagePlayHow.count", "Unknown should not be destroyed by Moderator, but...") do
      delete engage_play_how_url(EngagePlayHow.unknown)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
  end
end
