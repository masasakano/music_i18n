# coding: utf-8
require "test_helper"

class ChannelPlatformsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @channel_platform = channel_platforms(:channel_platform_oricon)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
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
    get channel_platforms_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_ja
    get channel_platforms_url
    assert_response :success
  end

  test "should get new" do
    sign_in @translator
    refute @translator.moderator?
    refute Ability.new(@translator).can?(:new, ChannelPlatform)
    get new_channel_platform_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @editor_ja
    get new_channel_platform_url
    assert_response :success
  end

  test "should create channel_platform" do
    hs2pass = @hs_create_lang.merge({ note: "", mname: "foo" })
    assert_no_difference("ChannelPlatform.count") do
      post channel_platforms_url, params: { channel_platform: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("ChannelPlatform.count") do
        post channel_platforms_url, params: { channel_platform: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @editor_ja
    #sign_in @syshelper
    run_test_create_null(ChannelPlatform) # defined in /test/helpers/controller_helper.rb

    assert_difference("ChannelPlatform.count") do
      post channel_platforms_url, params: { channel_platform: hs2pass }
    end
    eeih_last = ChannelPlatform.last
    assert_redirected_to channel_platform_url(eeih_last)
    assert_equal "foo", eeih_last.mname

    assert_no_difference("ChannelPlatform.count") do
      post channel_platforms_url, params: { channel_platform: { note: "", mname: "foobaa" } }
    end
    assert_response :unprocessable_entity
  end

  test "should show channel_platform" do
    get channel_platform_url(@channel_platform)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channel_platform_url(@channel_platform)
    assert_response :success, "Any editor should be able to read, but..."
  end

  test "should get edit" do
    sign_in @translator
    get edit_channel_platform_url(@channel_platform)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    assert_equal @editor_ja, @channel_platform.create_user, "sanity check. user=#{@channel_platform.inspect}"

    sign_in @moderator_harami
    get edit_channel_platform_url(@channel_platform)
    assert_response :redirect, "HARAMI-moderator should not be able to edit the entry created by @editor_ja, but..."
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @editor_ja
    get edit_channel_platform_url(@channel_platform)
    assert_response :success, "@editor_ja should be able to edit the entry created by themselves, but..."
    sign_out @editor_ja

    sign_in @moderator_ja
    get edit_channel_platform_url(@channel_platform)
    assert_response :success, "superior should be able to edit the entry created by subordinate, but..."
    sign_out @moderator_ja
  end

  test "should update channel_platform" do
    patch channel_platform_url(@channel_platform), params: { channel_platform: { note: @channel_platform.note, mname: "baa" } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    patch channel_platform_url(@channel_platform), params: { channel_platform: { note: @channel_platform.note, mname: "baa" } }
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @editor_ja
    patch channel_platform_url(@channel_platform), params: { channel_platform: { note: @channel_platform.note, mname: "baa" } }
    assert_redirected_to channel_platform_url(@channel_platform)
    assert_equal "baa", @channel_platform.reload.mname

    assert_redirected_to channel_platform_url(@channel_platform)
  end

  test "should destroy channel_platform" do
    sign_in @translator
    assert_no_difference("ChannelPlatform.count") do
      delete channel_platform_url(@channel_platform)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @translator

    sign_in @moderator_harami
    assert_no_difference("ChannelPlatform.count") do
      delete channel_platform_url(@channel_platform)
      assert_response :redirect
    end
    assert_redirected_to root_path, "non-creater fails to destroy it, and failure in deletion leads to Root-path"
    sign_out @moderator_harami

    sign_in @editor_ja
    #sign_in @syshelper
    assert_difference("ChannelPlatform.count", -1) do
      delete channel_platform_url(@channel_platform)
      assert_response :redirect
    end
    assert_redirected_to channel_platforms_url

    assert_no_difference("ChannelPlatform.count", "Unknown should not be destroyed by General editor, but...") do
      delete channel_platform_url(ChannelPlatform.unknown)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
  end
end
