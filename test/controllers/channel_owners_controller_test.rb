# coding: utf-8
require "test_helper"

class ChannelOwnersControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @channel_owner = channel_owners(:channel_owner_saki_kubota)
    @channel_owner2= channel_owners(:channel_owner_haramichan)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @validator = W3CValidators::NuValidator.new
    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    @hs_create_lang = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "best_translation_is_orig"=>str_form_for_nil,  # radio-button returns "on" for nil
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get channel_owners_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channel_owners_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @editor_ja
    get channel_owners_url
    assert_response :success
  end

  test "should get new" do
    sign_in @translator
    refute @translator.moderator?
    refute Ability.new(@translator).can?(:new, ChannelOwner)
    get new_channel_owner_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @editor_ja
    get new_channel_owner_url
    assert_response :success
  end

  test "should create channel_owner" do
    hs2pass = @hs_create_lang.merge({ note: "newno", themselves: false })
    assert_no_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("ChannelOwner.count") do
        post channel_owners_url, params: { channel_owner: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @editor_ja
    #sign_in @syshelper
    run_test_create_null(ChannelOwner, extra_colnames: %i(title langcode themselves)) # defined in /test/helpers/controller_helper.rb

    assert_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs2pass }
    end
    eeih_last = ChannelOwner.last
    assert_redirected_to channel_owner_url(eeih_last)
    assert_equal "newno", eeih_last.note

    assert_no_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs2pass.merge({ note: "same translation. should fail", themselves: true }) }
    end
    assert_response :unprocessable_entity
  end

  test "should show channel_owner" do
    get channel_owner_url(@channel_owner)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channel_owner_url(@channel_owner)
    assert_response :success, "Any editor should be able to read, but..."
    assert_base_with_translation_show_h2  # defined in /test/helpers/controller_helper.rb
  end

  test "should get edit" do
    sign_in @translator
    get edit_channel_owner_url(@channel_owner)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    assert_equal @editor_ja, @channel_owner.create_user, "sanity check. user=#{@channel_owner.inspect}"

    sign_in @moderator_harami
    get edit_channel_owner_url(@channel_owner)
    assert_response :redirect, "HARAMI-moderator should not be able to edit the entry created by @editor_ja, but..."
    assert_redirected_to root_path
    sign_out @moderator_harami

    sign_in @editor_ja
    get edit_channel_owner_url(@channel_owner)
    assert_response :success, "@editor_ja should be able to edit the entry created by themselves, but..."
    sign_out @editor_ja

    sign_in @moderator_ja
    get edit_channel_owner_url(@channel_owner)
    assert_response :success, "superior should be able to edit the entry created by subordinate, but..."
    assert_base_with_translation_show_h2  # defined in /test/helpers/controller_helper.rb
    sign_out @moderator_ja
  end

  test "should edit/update channel_owner" do
    sign_in @translator
    get edit_channel_owner_url(@channel_owner)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    #assert_equal @editor_ja, @channel_owner.create_user, "sanity check. user=#{@channel_owner.inspect}"

    newnote1 = "new-note"
    update_params = { channel_owner: { note: newnote1 } }

    sign_in @moderator_harami  # do  # if I put do, the next line is not executed for some reason! (maybe because another sign_in exists below?)
      get edit_channel_owner_url(@channel_owner)
      assert_response :redirect, "Harami-Moderator should not be able to edit the entry created by GA-editor, but..."
      assert_redirected_to root_path
      patch channel_owner_url(@channel_owner), params: update_params
      assert_response :redirect, "Harami-Moderator should not be able to update the entry created by GA-editor, but..."
      assert_redirected_to root_path
  
      orig_create_user = @channel_owner2.create_user
  
      get edit_channel_owner_url(@channel_owner2)
      assert_response :redirect, "Anyone but admins should not be able to edit the entry created by admin or no one, but..."
      assert_redirected_to root_path
      patch channel_owner_url(@channel_owner2), params: update_params
      assert_response :redirect, "Anyone but admins should not be able to update the entry created by admin or no one, but..."
      assert_redirected_to root_path
  
      @channel_owner2.update!(create_user: @editor_harami)
      patch channel_owner_url(@channel_owner2), params: update_params
      assert_response :redirect, "Harami-moderator cannot update an entry created by anyone, including their subordinates, but themselves, but..."
      refute_equal newnote1, @channel_owner2.reload.note
  
      @channel_owner2.update!(create_user: @moderator_harami)
      patch channel_owner_url(@channel_owner2), params: update_params
      assert_response :redirect
      assert_redirected_to @channel_owner2, "Harami-moderator should be able to update the entry created by themselves, but..."
      assert_equal newnote1, @channel_owner2.reload.note
    sign_out @moderator_harami

    sign_in @editor_ja # do
      @channel_owner2.update!(create_user: @moderator_harami, note: "orig0")
      assert_equal @moderator_harami, @channel_owner2.create_user, "sanity check"
      refute_equal newnote1, @channel_owner2.reload.note

      patch channel_owner_url(@channel_owner2), params: update_params
      assert_equal newnote1, @channel_owner2.reload.note
      assert_response :redirect
      assert_redirected_to @channel_owner2, "General-editor should be able to edit the entry created by anyone but admins, but..."

      @channel_owner2.update!(create_user: @moderator_harami, note: "orig0")
      assert_equal "orig0", @channel_owner2.reload.note

      patch channel_owner_url(@channel_owner2), params: update_params
      assert_response :redirect, "should not be able to update an entry, but..."
    #end
  end

  test "should destroy channel_owner" do
    sign_in @translator
    assert_no_difference("ChannelOwner.count") do
      delete channel_owner_url(@channel_owner)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @translator

    sign_in @moderator_harami
    assert_no_difference("ChannelOwner.count") do
      delete channel_owner_url(@channel_owner)
      assert_response :redirect
    end
    assert_redirected_to root_path, "non-creater fails to destroy it, and failure in deletion leads to Root-path"

    @channel_owner.update!(create_user: @moderator_harami)
    assert_difference("ChannelOwner.count", -1) do
      delete channel_owner_url(@channel_owner)
      assert_response :redirect
    end
    assert_redirected_to channel_owners_url

    sign_out @moderator_harami

    # See near the bottom of  test "should create channel_owner"  for @moderator_ja
  end
end
