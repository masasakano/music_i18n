# coding: utf-8
require "test_helper"

class DomainTitlesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @domain_title = domain_titles(:one)
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
    assert_operator 1, :<=, @domain_title.translations.size, "fixture testing: "+@domain_title.translations.inspect
    assert DomainTitle.unknown.unknown?, "fixture testing: "+DomainTitle.all.inspect

    assert_authorized_index(DomainTitle, fail_users: [@editor_harami], success_users: [@trans_moderator], h1_title: "Domain Titles") # defined in test_controller_helper.rb
  end

  test "should show/new/edit domain_title" do
    assert_authorized_show(@domain_title, fail_users: [@translator], success_users: [@trans_moderator], h1_title_regex: /^Domain Title: +#{Regexp.quote(@domain_title.title_or_alt)}/) # defined in test_controller_helper.rb

    refute Ability.new(@moderator_harami).can?(:new, DomainTitle)
    assert_authorized_new(  DomainTitle, fail_users: [@trans_moderator], success_users: [@moderator_ja], h1_title_regex: nil)

    assert_authorized_edit(@domain_title, fail_users: [@translator], success_users: [@moderator_ja], h1_title_regex: nil)
  end

  test "should create/update/destroy domain_title by moderator" do
    hs2pass = @hs_create_lang.merge({ site_category_id: @site_category.id.to_s, note: "test-create", memo_editor: "test-editor", weight: 111.24} )

    [nil, @translator, @trans_moderator].each do |ea_user|
      assert_equal :create, assert_unauthorized_post(DomainTitle, user: ea_user, params: hs2pass) # defined in test_controller_helper.rb
    end

    sign_in @moderator_ja
    assert_equal :create, assert_authorized_post(DomainTitle, params: hs2pass.merge({title: ""}), diff_num: 0).first # defined in test_controller_helper.rb
    action, new_mdl2 = assert_authorized_post(DomainTitle, params: hs2pass) # defined in test_controller_helper.rb
    assert_equal :create, action

### TODO
#    assert_difference("DomainTitle.count") do
#      post domain_titles_url, params: { domain_title: hs2pass.merge({title: new_mdl2.title}) }
#      assert_response :redirect, "identical title should be allowed for DomainTitle, but... (unless one of the Domains are identical)"+" Error-message: "+css_select('div#error_explanation').to_s  ############################################ TODO
#    end

    hs2pass2 = hs2pass.merge({title: new_mdl2.title+"01", })
    action, new_mdl3 = assert_authorized_post(DomainTitle, params: hs2pass2) # defined in test_controller_helper.rb
    assert_equal :create, action

    ### update/patch

    hsupdate = { site_category_id: new_mdl3.site_category.id.to_s,
                 note: new_mdl3.note,
                 memo_editor: new_mdl3.memo_editor,
                 weight: new_mdl3.weight }.with_indifferent_access

    action, tmp = assert_authorized_post(new_mdl3, params: hsupdate.merge(note: "aruyo"), updated_attrs: [:note]) # defined in test_controller_helper.rb
    assert_equal :update, action
    assert_equal tmp, new_mdl3  # sanity check, or test of  assert_authorized_post() itself.

    ### This fails expectedly in assertion!  This is the test of assert_authorized_post() itself.
    # assert_authorized_post(new_mdl3, params: hsupdate.merge(note: "aruyo"), updated_attrs: {note: 'wrong'})

    assert_raises(ArgumentError){
      assert_authorized_post(new_mdl3, params: hsupdate.merge(note: "aruyo"), updated_attrs: [:note, :id]) }
    sign_out @moderator_ja

    # User trans-editor denied access to update
    note3 = "aruyo3"
    action = assert_unauthorized_post(new_mdl3, user: @translator, params: hsupdate.merge(note: note3), unchanged_attrs: [:site_category_id, :memo_editor]){ # defined in test_controller_helper.rb
      refute_equal note3, new_mdl3.reload.note
    }
    assert :update, action

    ### destroy

    ## fail
    [nil, @translator].each do |ea_user|
      assert_equal :destroy, assert_unauthorized_post(new_mdl3, user: ea_user) # defined in test_controller_helper.rb
    end

    ## success
    action, _ =assert_authorized_post(new_mdl3, user: @moderator_ja) # defined in test_controller_helper.rb
    assert_equal :destroy, action
  end

end
