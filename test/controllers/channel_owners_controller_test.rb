# coding: utf-8
require "test_helper"

class ChannelOwnersControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  include ModuleCommon  # for definite_article_to_head(instr)

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

    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    @hs_create_lang = {
      "langcode"=>"ja",
      "title"=>"The Tｅst7",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      #"best_translation_is_orig"=>str_form_for_nil,  # radio-button returns "on" for nil
    }.with_indifferent_access
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
    hs2pass = @hs_create_lang.merge({ artist_id: "", artist_with_id: "", note: "newno", themselves: false })
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
    run_test_create_null(ChannelOwner, extra_colnames: %i(title langcode themselves)) # defined in test_controller_helper.rb

    # completely new Channel unrelated to an Artist
    assert_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs2pass }
      assert_response :redirect
    end
    eeih_last = ChannelOwner.last
    assert_redirected_to channel_owner_url(eeih_last)
    assert_equal "newno", eeih_last.note
    refute_equal @hs_create_lang[:title], eeih_last.title
    assert_equal preprocess_space_zenkaku(@hs_create_lang[:title]), definite_article_to_head(eeih_last.title) # defined in 

    assert_no_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs2pass.merge({ note: "same translation. should fail", themselves: true }) }
      assert_response :unprocessable_content
    end

    # Test of :artist_with_id
    art_lennon = artists(:artist2) # John Lennon
    art_with_id = BaseWithTranslation.base_with_translation_with_id_str art_lennon
    # hs = {langcode: "ja", title: "dummy", themselves: true, artist_with_id: art_with_id, note: "a007"}
    hs = {themselves: true, artist_with_id: art_with_id, note: "a007"}
    assert_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs }
      assert_response :redirect
    end
    mdl_last1 = ChannelOwner.last
    assert_equal "a007", mdl_last1.note, 'sanity check'
    assert_equal 3, art_lennon.translations.size, 'fixtures check'
    assert_equal %w(en ja), (ks=art_lennon.best_translations.keys).map(&:to_s).sort, 'fixtures check'

    _verify_assimilate_artist(art_lennon, mdl_last1)

    # 2nd time of :artist_with_id  - fails
    assert_no_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs }
      assert_response :unprocessable_content
    end

    # Change the status of JohnLennon Channel Owner to not-themselves.
    assert mdl_last1.update(themselves: false)

    # 3rd time of :artist_with_id  - success
    assert_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs }
      assert_response :redirect #, " Error-message: "+css_select('div#error_explanation').to_s
    end
    mdl_last2 = ChannelOwner.last
    assert mdl_last2.themselves
    _verify_assimilate_artist(art_lennon, mdl_last2)

    assert_equal mdl_last1.title, mdl_last2.title, "titles should be identical."
        
    # 4th time with title etc for an identical one with themselves==false - fails (because it is identical to mdl_last1 (with themselves=false)
    hs4th = {themselves: false, artist_id: "", artist_with_id: "", note: "a407"}
    hs4th.merge!(art_lennon.best_translation.attributes.slice(*%w(langcode title ruby romaji alt_title alt_ruby alt_romaji)))
    assert_no_difference("ChannelOwner.count") do
      post channel_owners_url, params: { channel_owner: hs4th }
      assert_response :unprocessable_content
    end

    sign_out @editor_ja

if false ############################# This should be implemented later.
    sign_in @trans_moderator
    tra_ai.title =  "new-one"
    tra_ai.save!
    tra_ai.reload
    %i(title weight update_user updated_at).each do |metho|
      assert_equal tra_ai.send(metho), tra_mdl.send(metho)
    end
end
  end

  def _verify_assimilate_artist(art, mdl)
    assert_equal art.title,             mdl.title, "mdl=#{mdl.inspect}"
    assert_equal art.romaji(langcode: 'ja'), mdl.romaji(langcode: 'ja'), "All best-translations (but not minor translations) should be copied but..."
    tra_ai  = art.best_translations[:en]
    tra_mdl = mdl.best_translations[:en]
    %i(title weight update_user updated_at).each do |metho|
      assert_equal tra_ai.send(metho), tra_mdl.send(metho), "tra_mdl=#{tra_mdl.inspect}"
    end
    assert_equal art.best_translations.size, mdl.best_translations.size
  end

  test "should show channel_owner" do
    get channel_owner_url(@channel_owner)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get channel_owner_url(@channel_owner)
    assert_response :success, "Any editor should be able to read, but..."
    assert_base_with_translation_show_h2  # defined in test_controller_helper.rb
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
    assert_base_with_translation_show_h2  # defined in test_controller_helper.rb
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
    artist1 = artists(:artist_proclaimers)
    update_params = { channel_owner: {
                        themselves: (@channel_owner2.themselves ? "1" : "0"),
                        artist_with_id: "",
                        artist_id: ((i=@channel_owner2.artist_id) ? i.to_s : ""),
                        note: newnote1 } }

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
      assert_response :redirect, "Harami-editor cannot update an entry created by anyone, including their subordinates, but themselves, but..."
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
      assert_response :redirect
      assert_equal newnote1, @channel_owner2.reload.note
      assert_redirected_to @channel_owner2, "General-editor should be able to edit the entry created by anyone but admins, but..."

      @channel_owner2.update!(create_user: @moderator_harami, note: "orig1")
      assert_equal "orig1", @channel_owner2.reload.note

      patch channel_owner_url(@channel_owner2), params: update_params
      assert_response :redirect, "should not be able to update an entry, but..."

    # Test of :artist_with_id
      @channel_owner2.update!(create_user: @editor_ja, note: "orig2")
      art_ai = artists(:artist_ai)
      art_with_id = BaseWithTranslation.base_with_translation_with_id_str art_ai
      hs_ai = {themselves: true, artist_with_id: art_with_id, note: "a007",
                                  artist_id: ((i=@channel_owner2.artist_id) ? i.to_s : ""),}  # artist_id: hidden
      patch channel_owner_url(@channel_owner2), params: { channel_owner: hs_ai }
      assert_response :redirect, "should not be able to update an entry, but..."
      @channel_owner2.reload
      assert_equal "a007", @channel_owner2.note, 'sanity check'

      _verify_assimilate_artist(art_ai, @channel_owner2)

    # Uncheck "themselves"
      hs_a2 = {themselves: false, artist_with_id: "", artist_id: art_ai.id.to_s, note: "a008"}  # artist_id: hidden
      patch channel_owner_url(@channel_owner2), params: { channel_owner: hs_a2 }
      assert_response :redirect, "should not be able to update an entry, but..."
      @channel_owner2.reload
      assert_equal "a008", @channel_owner2.note, 'sanity check'
      refute  @channel_owner2.themselves

    # Creates again Artist AI
      hs_a3 = {themselves: true, artist_with_id: art_with_id, artist_id: art_ai.id.to_s, note: "a019"}  # artist_id: hidden
      assert_difference("ChannelOwner.count") do
        post channel_owners_url, params: { channel_owner: hs_a3 }
        assert_response :redirect
      end
      mdl_last1 = ChannelOwner.last
      assert_equal "a019", mdl_last1.note
      assert  mdl_last1.themselves
      assert_equal art_ai, mdl_last1.artist
      assert_equal @channel_owner2.title, mdl_last1.title
      refute_equal @channel_owner2.themselves, mdl_last1.themselves
      upd = mdl_last1.updated_at

    # Uncheck "themselves" => fails (because the same translation with themselves=false exists.)
      hs_a4 = hs_a2.merge({note: "a99"})
      patch channel_owner_url(mdl_last1), params: { channel_owner: hs_a4 }
      assert_response :unprocessable_content
      mdl_last1.reload
      refute_equal "a99", mdl_last1.note, 'sanity check'
      assert_equal "a019", mdl_last1.note
      assert_equal upd,   mdl_last1.updated_at
      assert  mdl_last1.themselves
      assert_equal art_ai, mdl_last1.artist
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
