# coding: utf-8
require "test_helper"

class SiteCategoriesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
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
    get site_categories_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get site_categories_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get site_categories_url
    assert_response :success
    w3c_validate "Site Category index"  # defined in test_helper.rb (see for debugging help)
    sign_out @trans_moderator
  end

  test "should show site_category" do
    get site_category_url(@site_category)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get site_category_url(@site_category)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @trans_moderator
    get site_category_url(@site_category)
    assert_response :success, "Any moderator should be able to read, but..."
    w3c_validate "Site Category show"  # defined in test_helper.rb (see for debugging help)
    sign_out @trans_moderator
  end

  test "should get new" do
    sign_in @trans_moderator
    get new_site_category_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    refute Ability.new(@moderator_harami).can?(:new, SiteCategory)

    sign_in @moderator_ja
    get new_channel_type_url
    assert_response :success
  end

  test "should create/update/destroy site_category by moderator" do
    hs2pass = @hs_create_lang.merge({ mname: @site_category.mname+"ab", note: "test-create", memo_editor: "test-editor", summary: "test summary", weight: 111.24} )
    assert_no_difference("ChannelType.count") do
      post site_categories_url, params: { site_category: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("SiteCategory.count") do
        post site_categories_url, params: { site_category: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @moderator_ja
    assert_difference("SiteCategory.count") do
      post site_categories_url, params: { site_category: hs2pass }
      assert_response :redirect
    end
    assert_redirected_to site_category_url(new_mdl2 = SiteCategory.last)

    assert_no_difference("SiteCategory.count") do
      post site_categories_url, params: { site_category: hs2pass.merge({title: "", mname: __method__.to_s+"03"}) }
      assert_response :unprocessable_entity, "should have failed due to null title, but..."
    end

    assert_no_difference("SiteCategory.count") do
      post site_categories_url, params: { site_category: hs2pass.merge({title: new_mdl2.title, mname: __method__.to_s+"03"}) }
      assert_response :unprocessable_entity, "should have failed due to an identical title, but..."
    end

    hs2pass2 = hs2pass.merge({title: new_mdl2.title+"01", mname: new_mdl2.mname, })
    assert_no_difference("SiteCategory.count") do
      post site_categories_url, params: { site_category: hs2pass2 }
      assert_response :unprocessable_entity, "should have failed due to an identical mname, but..."
    end

    hs2pass2 = hs2pass.merge({title: new_mdl2.title+"01", mname: __method__.to_s+"03", })
    assert_difference("SiteCategory.count") do  # "should succeede, but..."
      post site_categories_url, params: { site_category: hs2pass2 }
      assert_response :redirect
    end
    assert_redirected_to site_category_url(new_mdl3 = SiteCategory.last)

    ### update/patch

    hsupdate = { mname: new_mdl3.mname, note: new_mdl3.note, memo_editor: new_mdl3.memo_editor, summary: new_mdl3.summary, weight: new_mdl3.weight }.with_indifferent_access
    patch site_category_url(new_mdl3), params: { site_category: hsupdate.merge(note: "aruyo") }
    assert_redirected_to site_category_url(new_mdl3)
    assert_equal "aruyo", new_mdl3.reload.note

    sign_out @moderator_ja

    # User trans-editor
    sign_in @translator

    note3 = "aruyo3"
    patch site_category_url(new_mdl3), params: { site_category: hsupdate.merge(note: note3) }
    assert_response :redirect
    assert_redirected_to root_path, "should be redirected before entering Controller"
    refute_equal note3, new_mdl3.reload.note

    ### destroy

    assert_no_difference("SiteCategory.count") do
      delete site_category_url(new_mdl3)
      assert_response :redirect
    end
    sign_out @translator

    sign_in @moderator_ja
    assert_difference("SiteCategory.count", -1) do
      delete site_category_url(new_mdl3)
      assert_response :redirect
    end
    assert_redirected_to site_categories_url
    sign_out @moderator_ja
  end

  test "should get edit" do
    sign_in @translator
    get edit_site_category_url(@site_category)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @moderator_ja
    get edit_site_category_url(@site_category)
    assert_response :success
    sign_out @moderator_ja
  end

end
