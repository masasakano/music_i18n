# coding: utf-8
require "test_helper"

class DomainNamesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @domain_name = domain_names(:one)
    @site_category = site_categories(:one)
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
      "title"=>"The Tｅst12",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "best_translation_is_orig"=>str_form_for_nil,  # radio-button returns "on" for nil
    }.with_indifferent_access
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    assert_operator 1, :<=, @domain_name.translations.size, "fixture testing: "+@domain_name.translations.inspect
    assert DomainName.unknown.unknown?, "fixture testing: "+DomainName.all.inspect

    get domain_names_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get domain_names_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get domain_names_url
    assert_response :success
    w3c_validate "Site Category index"  # defined in test_helper.rb (see for debugging help)
    sign_out @trans_moderator
  end

  test "should show domain_name" do
    get domain_name_url(@domain_name)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get domain_name_url(@domain_name)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @trans_moderator
    get domain_name_url(@domain_name)
    assert_response :success, "Any moderator should be able to read, but..."
    w3c_validate "Site Category show"  # defined in test_helper.rb (see for debugging help)
    sign_out @trans_moderator
  end

  test "should get new" do
    sign_in @trans_moderator
    get new_domain_name_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    refute Ability.new(@moderator_harami).can?(:new, DomainName)

    sign_in @moderator_ja
    get new_domain_name_url
    assert_response :success
  end

  test "should create/update/destroy domain_name by moderator" do
    hs2pass = @hs_create_lang.merge({ site_category_id: @site_category.id.to_s, note: "test-create", memo_editor: "test-editor", weight: 111.24} )
    assert_no_difference("ChannelType.count") do
      post domain_names_url, params: { domain_name: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("DomainName.count") do
        post domain_names_url, params: { domain_name: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @moderator_ja
    assert_difference("DomainName.count") do
      post domain_names_url, params: { domain_name: hs2pass }
      assert_response :redirect
    end
    assert_redirected_to domain_name_url(new_mdl2 = DomainName.last)

    assert_no_difference("DomainName.count") do
      post domain_names_url, params: { domain_name: hs2pass.merge({title: ""}) }
      assert_response :unprocessable_entity, "should have failed due to null title, but..."
    end

    assert_difference("DomainName.count") do
      post domain_names_url, params: { domain_name: hs2pass.merge({title: new_mdl2.title}) }
      assert_response :redirect, "identical title is allowed for DomainName! (unless one of the Domains are identical)"  ############################################ TODO
    end

    hs2pass2 = hs2pass.merge({title: new_mdl2.title+"01", })
    assert_difference("DomainName.count") do  # "should succeede, but..."
      post domain_names_url, params: { domain_name: hs2pass2 }
      assert_response :redirect
    end
    assert_redirected_to domain_name_url(new_mdl3 = DomainName.last)

    ### update/patch

    hsupdate = { site_category_id: new_mdl3.site_category.id.to_s,
                 note: new_mdl3.note,
                 memo_editor: new_mdl3.memo_editor,
                 weight: new_mdl3.weight }.with_indifferent_access
    patch domain_name_url(new_mdl3), params: { domain_name: hsupdate.merge(note: "aruyo") }
    assert_redirected_to domain_name_url(new_mdl3)
    assert_equal "aruyo", new_mdl3.reload.note

    sign_out @moderator_ja

    # User trans-editor
    sign_in @translator

    note3 = "aruyo3"
    patch domain_name_url(new_mdl3), params: { domain_name: hsupdate.merge(note: note3) }
    assert_response :redirect
    assert_redirected_to root_path, "should be redirected before entering Controller"
    refute_equal note3, new_mdl3.reload.note

    ### destroy

    assert_no_difference("DomainName.count") do
      delete domain_name_url(new_mdl3)
      assert_response :redirect
    end
    sign_out @translator

    sign_in @moderator_ja
    assert_difference("DomainName.count", -1) do
      delete domain_name_url(new_mdl3)
      assert_response :redirect
    end
    assert_redirected_to domain_names_url
    sign_out @moderator_ja
  end

  test "should get edit" do
    sign_in @translator
    get edit_domain_name_url(@domain_name)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @moderator_ja
    get edit_domain_name_url(@domain_name)
    assert_response :success
    sign_out @moderator_ja
  end

end
