# coding: utf-8
require "test_helper"

class ChannelsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @channel1 = @channel = channels(:one)
    @channel2= channels(:channel_haramichan_youtube_main)
    #@channel_owner = channel_owners(:channel_owner_saki_kubota)
    #@channel_owner2= channel_owners(:channel_owner_haramichan)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    @hs_create_lang = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      #"best_translation_is_orig"=>str_form_for_nil,  # radio-button returns "on" for nil
    }.with_indifferent_access

    @hs_basics = {
      id_at_platform: "",
      id_human_at_platform: "",
    }.with_indifferent_access
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get channels_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channels_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @editor_ja
    get channels_url
    assert_response :success
  end

  test "should get new" do
    sign_in @translator
    refute @translator.moderator?
    refute Ability.new(@translator).can?(:new, Channel)
    get new_channel_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @editor_ja
    get new_channel_url
    assert_response :success
  end

  test "should create channel" do
    hs2pass = @hs_create_lang.merge(@hs_basics).merge({ channel_owner_id: @channel.channel_owner.id, channel_platform_id: ChannelPlatform.unknown.id, channel_type_id: @channel.channel_type.id, note: "newno", })
    assert_no_difference("Channel.count") do
      post channels_url, params: { channel: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("Channel.count") do
        post channels_url, params: { channel: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @editor_ja
    #sign_in @syshelper
    run_test_create_null(Channel, extra_colnames: %i(title langcode)) # defined in /test/helpers/controller_helper.rb
    ## null imput should fail.

    assert_difference("Channel.count") do
      post channels_url, params: { channel: hs2pass }
    end
    eeih_last = Channel.last
    assert_redirected_to channel_url(eeih_last)
    assert_equal "newno", eeih_last.note

    assert_no_difference("Channel.count") do
      post channels_url, params: { channel: hs2pass.merge({ note: "same parameters. should fail" }) }
    end
    assert_response :unprocessable_entity

    platform_fb = channel_platforms(:channel_platform_facebook)
    assert_difference("Channel.count", 1, "An existing translation should be allowed as long as the combination of the main three parameters is unique, but...") do
      post channels_url, params: { channel: hs2pass.merge({title: @channel2.title(langcode: :en), channel_platform_id: platform_fb.id }.with_indifferent_access) }
      assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
    end
    eeih_last = Channel.last
    assert_redirected_to channel_url(eeih_last)
    sign_out @editor_ja
  end

  test "should show channel" do
    get channel_url(@channel)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channel_url(@channel)
    assert_response :success, "Any editor should be able to read, but..."
    assert_base_with_translation_show_h2  # defined in /test/helpers/controller_helper.rb
  end

  test "should get edit" do
    sign_in @translator
    get edit_channel_url(@channel)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    assert_equal @editor_ja, @channel.create_user, "sanity check. user=#{@channel.inspect}"

    ### Specs changed after ver.1.5 -- now anyone can edit or destroy Channel created by anyone but admin
    # sign_in @moderator_harami
    # get edit_channel_url(@channel)
    # assert_response :redirect, "HARAMI-moderator should not be able to edit the entry created by @editor_ja, but..."
    # assert_redirected_to root_path
    # sign_out @moderator_harami

    sign_in @editor_ja
    get edit_channel_url(@channel)
    assert_response :success, "@editor_ja should be able to edit the entry created by themselves, but..."
    sign_out @editor_ja

    sign_in @moderator_ja
    get edit_channel_url(@channel)
    assert_response :success, "superior should be able to edit the entry created by subordinate, but..."
    assert_base_with_translation_show_h2  # defined in /test/helpers/controller_helper.rb
    sign_out @moderator_ja
  end

  test "should update channel" do
    sign_in @translator
    get edit_channel_url(@channel)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    #assert_equal @editor_ja, @channel.create_user, "sanity check. user=#{@channel.inspect}"

    newnote1 = "new-note"
    update_params = { channel: { channel_type_id: ChannelType.unknown.id, note: newnote1 } }.with_indifferent_access

    # Sets id_at_platform, id_human_at_platform
    chans = [@channel, @channel2]
    update_paramss = {
      1 => { channel: update_params[:channel] },
      2 => { channel: update_params[:channel] },
    }
    (1..2).each do |eid|
      hstmp = {}.with_indifferent_access
      @hs_basics.each_key do |ek|  # id_at_platform, id_human_at_platform
        hstmp[ek] = (@channel.send(ek) || "")  # Always "" (but nil) is passed from from.
      end
      %i(channel_owner_id channel_platform_id).each do |ek|
        hstmp[ek] = chans[eid-1].send(ek)
      end
      update_paramss[eid][:channel] = update_paramss[eid][:channel].merge(hstmp)
    end

    sign_in @moderator_harami  # do  # if I put do, the next line is not executed for some reason! (maybe because another sign_in exists below?)
      ### Specs changed after ver.1.5 -- now anyone can edit or destroy Channel created by anyone but admin
      # get edit_channel_url(@channel)
      # assert_response :redirect, "Harami-Moderator should not be able to edit the entry created by GA-editor, but..."
      # assert_redirected_to root_path
      # patch channel_url(@channel), params: update_paramss[1]
      # assert_response :redirect, "Harami-Moderator should not be able to update the entry created by GA-editor, but..."
      # assert_redirected_to root_path
  
      orig_create_user = @channel2.create_user
  
      ### Specs changed after ver.1.5 -- now anyone can edit or destroy Channel created by anyone but admin
      # get edit_channel_url(@channel2)
      # assert_response :redirect, "Anyone but admins should not be able to edit the entry created by admin or no one, but..."
      # assert_redirected_to root_path
      # patch channel_url(@channel2), params: update_paramss[2]
      # assert_response :redirect, "Anyone but admins should not be able to update the entry created by admin or no one, but..."
      # assert_redirected_to root_path
  
      # @channel2.update!(create_user: @editor_harami)
      # patch channel_url(@channel2), params: update_paramss[2]
      # assert_response :redirect, "Harami-moderator cannot update an entry created by anyone, including their subordinates, but themselves, but..."
      # refute_equal newnote1, @channel2.reload.note

      @channel2.update!(create_user: @moderator_harami)
      patch channel_url(@channel2), params: update_paramss[2]
      assert_response :redirect
      assert_redirected_to @channel2, "Harami-moderator should be able to update the entry created by themselves, but..."
      assert_equal newnote1, @channel2.reload.note

      # Testing updating id_human_at_platform - "@" should be removed if specified.
      tmpid_human = "abcde"
      patch channel_url(@channel2), params: {channel: update_paramss[2][:channel].merge({id_human_at_platform: "@"+tmpid_human}.with_indifferent_access) }
      assert_response :redirect
      assert_redirected_to @channel2, "Harami-moderator should be able to update the entry created by themselves, but..."
      assert_equal "@"+tmpid_human, @channel2.reload.id_human_at_platform
      @channel2.update!(id_human_at_platform: nil)

      # Testing updating id_human_at_platform - 1 character is too short.
      tmpid_human = "X"
      patch channel_url(@channel2), params: {channel: update_paramss[2][:channel].merge({id_human_at_platform: tmpid_human}.with_indifferent_access) }
      assert_response :unprocessable_entity
      assert_nil  @channel2.reload.id_human_at_platform  # no change

      # Testing updating id_at_platform - 1 character is too short.
      assert_nil  @channel2.id_at_platform  # sanity check
      tmpid_human = "X"
      patch channel_url(@channel2), params: {channel: update_paramss[2][:channel].merge({id_at_platform: tmpid_human}.with_indifferent_access) }
      assert_response :unprocessable_entity
      assert_nil  @channel2.reload.id_at_platform  # no change
    sign_out @moderator_harami

    sign_in @editor_ja # do
      @channel2.update!(create_user: @moderator_harami, note: "orig0")
      assert_equal @moderator_harami, @channel2.create_user, "sanity check"
      refute_equal newnote1, @channel2.reload.note

      patch channel_url(@channel2), params: update_paramss[2]
      assert_equal newnote1, @channel2.reload.note
      assert_response :redirect
      assert_redirected_to @channel2, "General-editor should be able to edit the entry created by anyone but admins, but..."

      @channel2.update!(create_user: @moderator_harami, note: "orig0")
      assert_equal "orig0", @channel2.reload.note

      patch channel_url(@channel2), params: update_paramss[2]
      assert_response :redirect, "should not be able to update an entry, but..."

    #end
    sign_out @editor_ja
  end

  test "should destroy channel" do
    refute @channel.create_user.an_admin?, 'sanity check...'

    sign_in @translator
    assert_no_difference("Channel.count") do
      delete channel_url(@channel)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @translator

    sign_in @moderator_harami
    assert_difference("Channel.count", -1) do
      delete channel_url(@channel)
      assert_response :redirect
    end
    assert_redirected_to channels_url
    # assert_redirected_to root_path, "non-creater fails to destroy it, and failure in deletion leads to Root-path"  # => specs changed

    ### Now (because the specs changed), the model has been already destroyed.
    # @channel.update!(create_user: @moderator_harami)
    # assert_difference("Channel.count", -1) do
    #   delete channel_url(@channel)
    #   assert_response :redirect
    # end
    # assert_redirected_to channels_url

    sign_out @moderator_harami

  end
end
