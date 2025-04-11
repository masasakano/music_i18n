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

    get domains_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get domains_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get domains_url
    assert_response :success
    w3c_validate "Site Category index"  # defined in test_helper.rb (see for debugging help)
    sign_out @trans_moderator
  end

  test "should show domain" do
    get domain_url(@domain)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @translator
    get domain_url(@domain)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @trans_moderator
    get domain_url(@domain)
    assert_response :success, "Any moderator should be able to read, but..."
    w3c_validate "Site Category show"  # defined in test_helper.rb (see for debugging help)
    sign_out @trans_moderator
  end

  test "should get new" do
    sign_in @trans_moderator
    get new_domain_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    refute Ability.new(@moderator_harami).can?(:new, Domain)

    sign_in @moderator_ja
    get new_domain_url
    assert_response :success
  end

  test "should create/update/destroy domain by moderator" do
    hs2pass = @hs_base.merge({ note: "test-create", weight: 111.24} )
    assert_no_difference("ChannelType.count") do
      post domains_url, params: { domain: hs2pass }
    end

    [@translator, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("Domain.count") do
        post domains_url, params: { domain: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @moderator_ja
    assert_difference("Domain.count") do
      post domains_url, params: { domain: hs2pass }
      assert_response :redirect
    end
    assert_redirected_to domain_url(new_mdl2 = Domain.last)

    assert_no_difference("Domain.count") do
      post domains_url, params: { domain: hs2pass }
      assert_response :unprocessable_entity, "should have failed due to unique constraint, but..."
    end

    assert_no_difference("Domain.count") do
      post domains_url, params: { domain: hs2pass.merge({domain: ""}) }
      assert_response :unprocessable_entity, "should have failed due to null title, but..."
    end

    assert_no_difference("Domain.count") do
      post domains_url, params: { domain: hs2pass.merge({domain: new_mdl2.domain+".012" }) }
      assert_response :unprocessable_entity, "should have failed due to the invalid domain name, but..."
    end

    hs2pass2 = hs2pass.merge({domain: "another."+new_mdl2.domain, })
    assert_difference("Domain.count") do  # "should succeed, but..."
      post domains_url, params: { domain: hs2pass2 }
      assert_response :redirect
    end
    assert_redirected_to domain_url(new_mdl3 = Domain.last)

    ### update/patch

    newdomain = "xyz.something.org"
    hsupdate = { domain: newdomain,
                 domain_title_id: new_mdl3.domain_title.id.to_s,
                 note: new_mdl3.note,
                 weight: new_mdl3.weight }.with_indifferent_access
    patch domain_url(new_mdl3), params: { domain: hsupdate.merge(note: "aruyo") }
    assert_redirected_to domain_url(new_mdl3)
    assert_equal "aruyo",   new_mdl3.reload.note
    assert_equal newdomain, new_mdl3.reload.domain

    sign_out @moderator_ja

    # User trans-editor
    sign_in @translator

    note3 = "aruyo3"
    patch domain_url(new_mdl3), params: { domain: hsupdate.merge(note: note3) }
    assert_response :redirect
    assert_redirected_to root_path, "should be redirected before entering Controller"
    refute_equal note3, new_mdl3.reload.note

    ### destroy

    assert_no_difference("Domain.count") do
      delete domain_url(new_mdl3)
      assert_response :redirect
    end
    sign_out @translator

    sign_in @moderator_ja
    assert_difference("Domain.count", -1) do
      delete domain_url(new_mdl3)
      assert_response :redirect
    end
    assert_redirected_to domains_url
    sign_out @moderator_ja
  end

  test "should get edit" do
    sign_in @translator
    get edit_domain_url(@domain)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @moderator_ja
    get edit_domain_url(@domain)
    assert_response :success
    sign_out @moderator_ja
  end

end
