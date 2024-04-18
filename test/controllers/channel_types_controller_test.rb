# coding: utf-8
require "test_helper"

class ChannelTypesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @channel_type = channel_types(:one)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
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
    get channel_types_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get channel_types_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get channel_types_url
    assert_response :success
  end

  test "should show channel_type" do
    get channel_type_url(@channel_type)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channel_type_url(@channel_type)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @moderator_harami
    get channel_type_url(@channel_type)
    assert_response :success, "Any moderator should be able to read, but..."
  end

  test "should get new" do
    sign_in @trans_moderator
    get new_channel_type_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    sign_in @moderator_harami
    assert Ability.new(@moderator_harami).can?(:new, ChannelType)
    get new_channel_type_url
    assert_response :success
  end

  test "should create channel_type" do
    hs2pass = @hs_create_lang.merge({ note: "", mname: "foo", weight: ChannelType.new_unique_max_weight })
    assert_no_difference("ChannelType.count") do
      post channel_types_url, params: { channel_type: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("ChannelType.count") do
        post channel_types_url, params: { channel_type: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @moderator_ja
    #sign_in @syshelper
    assert_difference("ChannelType.count") do
      post channel_types_url, params: { channel_type: hs2pass }
    end
    new_mdl1 = ChannelType.order(:created_at).last
    assert_redirected_to channel_type_url(new_mdl1)
    assert_equal "foo", new_mdl1.mname

    assert_no_difference("ChannelType.count") do
      post channel_types_url, params: { channel_type: { note: "", mname: "foobaa", weight: ChannelType.new_unique_max_weight } }  # Error b/c/ no Translation is given.
    end
    assert_response :unprocessable_entity

    assert_no_difference("ChannelType.count") do
      post channel_types_url, params: { channel_type: hs2pass.merge({mname: "foobaa", weight: ChannelType.new_unique_max_weight}) }
    end
    assert_response :unprocessable_entity

    assert_difference("ChannelType.count") do
      post channel_types_url, params: { channel_type: hs2pass.merge({mname: "foobaa", weight: ChannelType.new_unique_max_weight, title: new_mdl1.title+"_abc"}) }
    end
    new_mdl2 = ChannelType.order(:created_at).last
    assert_redirected_to channel_type_url(new_mdl2)
    sign_out @moderator_ja

    sign_in @moderator_harami
    assert_difference("ChannelType.count") do
      post channel_types_url, params: { channel_type: hs2pass.merge({mname: "hoocbb", weight: ChannelType.new_unique_max_weight, title: new_mdl1.title+"_moderator_harami"}) }
    end
    new_mdl3 = ChannelType.order(:created_at).last
    assert_redirected_to channel_type_url(new_mdl3)

    ### update/patch

    [@channel_type, new_mdl2].each do |ea_mo|
      patch channel_type_url(ea_mo), params: { channel_type: { note: @channel_type.note, mname: "baa" } }
      assert_response :redirect
      refute_equal "baa", ea_mo.reload.mname
    end

    patch channel_type_url(new_mdl3), params: { channel_type: { note: @channel_type.note, mname: "baa" } }
    assert_response :redirect
    assert_equal "baa", new_mdl3.reload.mname, "should be able to update those created by themselves"

    sign_out @moderator_harami

    # User with no priviledge
    patch channel_type_url(@channel_type), params: { channel_type: { note: @channel_type.note, mname: "baa" } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    # User trans-editor
    sign_in @translator
    patch channel_type_url(@channel_type), params: { channel_type: { note: @channel_type.note, mname: "pqr" } }
    assert_response :redirect
    assert_redirected_to root_path, "should be redirected before entering Controller"
    refute_equal "pqr", @channel_type.reload.mname
    sign_out @translator

    # User with Ga moderator
    sign_in @moderator_ja
    patch channel_type_url(@channel_type), params: { channel_type: { note: @channel_type.note, mname: "pqr" } }
    assert_response :redirect
    assert_redirected_to root_path
    refute_equal "pqr", @channel_type.reload.mname

    assert_equal @moderator_harami, new_mdl3.create_user, "sanity check"
    patch channel_type_url(new_mdl3), params: { channel_type: { note: @channel_type.note, mname: "pqr" } }
    assert_response :redirect
    assert_redirected_to channel_type_url(new_mdl3)
    assert_equal "pqr", new_mdl3.reload.mname, "GA moderator should be able to edit those created by other moderators"

    ### destroy

    assert_no_difference("ChannelType.count") do
      delete channel_type_url(@channel_type)
      assert_response :redirect
    end
    #assert_redirected_to channel_types_url, "fails to destroy it, and failure in deletion leads to index"  # redirection destination depends on the referrer; in this test, it is root_path.

    assert_difference("ChannelType.count", -1) do
      delete channel_type_url(new_mdl3)
      assert_response :redirect
    end
    assert_difference("ChannelType.count", -1) do
      delete channel_type_url(new_mdl2)
      assert_response :redirect
    end
    assert_redirected_to channel_types_url
    sign_out @moderator_ja
  end

  test "should get edit" do
    sign_in @translator
    get edit_channel_type_url(@channel_type)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    #assert_equal @editor_ja, @channel_type.create_user, "sanity check. user=#{@channel_type.inspect}"

    sign_in @moderator_ja
    get edit_channel_type_url(@channel_type)
    assert_response :redirect, "Anyone but admins should not be able to edit the entry created by admin or no one, but..."
    assert_redirected_to root_path
    sign_out @moderator_ja

    channel_type_media = channel_types(:channel_type_media)
    orig_create_user = channel_type_media.create_user

    sign_in @moderator_harami
    get edit_channel_type_url(channel_type_media)
    assert_response :redirect, "Anyone but admins should not be able to edit the entry created by admin or no one, but..."
    assert_redirected_to root_path

    channel_type_media.update!(create_user: @editor_harami)
    get edit_channel_type_url(channel_type_media)
    assert_response :redirect, "Harami-moderator cannot edit an entry created by anyone, including their subordinates, but themselves, but..."

    channel_type_media.update!(create_user: @moderator_harami)
    get edit_channel_type_url(channel_type_media)
    assert_response :success, "@editor_ja should be able to edit the entry created by themselves, but..."
    sign_out @moderator_harami

    sign_in @editor_ja
    get edit_channel_type_url(channel_type_media)
    assert_response :redirect, "should not be able to edit an entry, but..."

    channel_type_media.update!(create_user: @editor_ja)
    get edit_channel_type_url(channel_type_media)
    assert_response :redirect, "should not be able to edit an entry, but..."
    sign_out @editor_ja

    sign_in @moderator_ja
    get edit_channel_type_url(@channel_type)
    assert_response :redirect, "should not be able to edit an entry, but..."

    channel_type_media.update!(create_user: @moderator_harami)
    get edit_channel_type_url(channel_type_media)
    assert_response :success, "General-moderator should be able to edit the entry created by anyone but admins, but..."

    channel_type_media.update!(create_user: @moderator_ja)
    get edit_channel_type_url(channel_type_media)
    assert_response :success, "should be able to edit the entry created by anyone but admins, but..."
    sign_out @moderator_ja
  end

  test "should destroy channel_type" do
    sign_in @translator
    assert_no_difference("ChannelType.count") do
      delete channel_type_url(@channel_type)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @translator

    sign_in @moderator_harami
    assert_no_difference("ChannelType.count") do
      delete channel_type_url(@channel_type)
      assert_response :redirect
    end
    assert_redirected_to root_path, "non-creater fails to destroy it, and failure in deletion leads to Root-path"

    @channel_type.update!(create_user: @moderator_harami)
    assert_difference("ChannelType.count", -1) do
      delete channel_type_url(@channel_type)
      assert_response :redirect
    end
    assert_redirected_to channel_types_url

    sign_out @moderator_harami

    # See near the bottom of  test "should create channel_type"  for @moderator_ja
  end
end
