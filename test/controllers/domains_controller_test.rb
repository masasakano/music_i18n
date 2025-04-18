require "test_helper"

class DomainsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @domain = domains(:one)
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

    @hs_base = { domain: "mytest.mysite.com", domain_title_id: @domain_title.id.to_s, note: nil, weight: 111.24}
    #str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    assert Domain.unknown.unknown?, "fixture testing: "+Domain.all.inspect

    assert_authorized_index(Domain, fail_users: [@editor_harami], success_users: [@trans_moderator], h1_title: "Domains") # defined in /test/helpers/controller_helper.rb
  end

  test "should show/new/edit domain" do
    # Any moderator should be able to read
    assert_authorized_show(@domain, fail_users: [@translator], success_users: [@trans_moderator], h1_title_regex: /^Domain: +#{Regexp.quote(@domain.domain)}/) # defined in /test/helpers/controller_helper.rb

    assert_authorized_new(  Domain, fail_users: [@trans_moderator], success_users: [@moderator_ja], h1_title_regex: nil)
    refute Ability.new(@moderator_harami).can?(:new, Domain)

    assert_authorized_edit(@domain, fail_users: [@translator], success_users: [@moderator_ja], h1_title_regex: nil)
  end

  test "should create/update/destroy domain by moderator" do
    hs2pass = @hs_base.merge({ note: "test-create", weight: 111.24} )
    [nil, @translator, @trans_moderator].each do |ea_user|
      assert_equal :create, assert_unauthorized_post(Domain, user: ea_user, params: hs2pass, bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    end

    sign_in @moderator_ja
    action, new_mdl2 = assert_authorized_post(Domain, params: hs2pass, bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    assert_equal :create, action

    assert_equal :create, assert_authorized_post(Domain, params: hs2pass, diff_num: 0, err_msg: "should have failed due to unique constraint, but Response is...", bind_offset: 0).first # defined in /test/helpers/controller_helper.rb
    # assert_authorized_post(Domain, params: hs2pass.merge(domain: "yy.com"), diff_num: 0, err_msg: "should have failed due to unique constraint, but Response is...", bind_offset: 0)  ## This expectantly fails!  A test of assert_authorized_post() itself.

    assert_equal :create, assert_authorized_post(Domain, params: hs2pass.merge({domain: ""}), diff_num: 0, err_msg: "should have failed due to null title, but Response is...", bind_offset: 0).first
    assert_equal :create, assert_authorized_post(Domain, params: hs2pass.merge({domain: new_mdl2.domain+".012" }), diff_num: 0, err_msg: "should have failed due to the invalid domain name, but Response is...", bind_offset: 0).first

    hs2pass2 = hs2pass.merge({domain: "another."+new_mdl2.domain, })
    action, new_mdl3 = assert_authorized_post(Domain, params: hs2pass2, bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    assert_equal :create, action

    ### update/patch

    newdomain = "xyz.something.org"
    hsupdate = { domain: newdomain,
                 domain_title_id: new_mdl3.domain_title.id.to_s,
                 note: new_mdl3.note,
                 weight: new_mdl3.weight }.with_indifferent_access
    
    action, _ = assert_authorized_post(new_mdl3, params: hsupdate.merge(note: "aruyo"), updated_attrs: [:note, :domain], bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    assert_equal :update, action

    sign_out @moderator_ja

    # User trans-editor

    note3 = "aruyo3"
    assert_equal :update, assert_unauthorized_post(new_mdl3, user: @translator, params: hsupdate.merge(note: note3), unchanged_attrs: [:note], bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    
    ### destroy

    ## fail
    [nil, @translator].each do |ea_user|
      assert_equal :destroy, assert_unauthorized_post(new_mdl3, user: ea_user, bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    end

    ## success
    action, _ =assert_authorized_post(new_mdl3, user: @moderator_ja, bind_offset: 0) # defined in /test/helpers/controller_helper.rb
    assert_equal :destroy, action

  end

end
