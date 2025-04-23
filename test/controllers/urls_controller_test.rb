# coding: utf-8
require "test_helper"

class UrlsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @url = urls(:one)
    @domain = domains(:one)
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
    @hs_base = {
      url: "",  # mandatory
      url_langcode: "",
      domain_id: "",  # mandatory at the model level but not in Controller
      weight: "",
      note: "",
      memo_editor: nil,
    }.merge(
      %w(published_date last_confirmed_date).map{|ew|
        [1,2,3].map{|i| [sprintf("%s(%di)", ew, i), ""]}.to_h  # WARNING: nil instaed of "" would cause a weird Rails-level error of "undefined method `empty?'"
      }.inject({}){|i,j| i.merge j}
    ).with_indifferent_access
    ## NOTE: you may use: ApplicationHelper#get_params_from_date_time
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    assert_authorized_index(Url, fail_users: [@translator], success_users: [@editor_ja, @editor_harami], h1_title: nil) # defined in /test/helpers/controller_helper.rb
  end


  test "should show/new/edit url" do
    assert_authorized_show(@url, fail_users: [@translator], success_users: [@editor_ja, @editor_harami], h1_title_regex: nil)

    assert_authorized_new(  Url, fail_users: [@translator], success_users: [@editor_ja, @editor_harami], h1_title_regex: nil)

    assert_authorized_edit(@url, fail_users: [@translator], success_users: [@editor_ja, @editor_harami], h1_title_regex: nil)
  end


  test "should create/update/destroy url by moderator" do
    calc_count_exp = 'Translation.count*1000 + DomainTitle.count*100 + Domain.count*10 + Url.count'

    newurl = @domain.domain+"/newabc.html?q=123&r=456#anch"
    hs2add = { url: newurl, domain_id: @domain.id.to_s, note: "test-create", memo_editor: "test-editor", weight: 111.24}
    hs2pass = @hs_create_lang.merge(@hs_base).merge( hs2add )

    [nil, @translator].each do |ea_user|  # @trans_moderator may be pviviledged?
      assert_equal :create, assert_unauthorized_post(Url, user: ea_user, params: hs2pass) # defined in /test/helpers/controller_helper.rb
    end

    sign_in @moderator_ja
    ## Successful creation of Url with existing Domain and DomainTitle
    action, new_mdl2 = assert_authorized_post(Url, params: hs2pass, diff_count_command: calc_count_exp, diff_num: 1001) # defined in /test/helpers/controller_helper.rb
    assert_equal :create, action

    hs2pass2 = hs2pass.merge(title: "new 2 pass")  # makes title be different in default.
    assert_equal :create, assert_authorized_post(Url, params: hs2pass2, diff_num: 0, err_msg: "should have failed due to unique constraint of url, but Response is...").first # defined in /test/helpers/controller_helper.rb

    assert_equal :create, assert_authorized_post(Url, params: hs2pass.merge({title: ""}), diff_num: 0, err_msg: "null title should not be allowed, but Response is...").first # defined in /test/helpers/controller_helper.rb

    assert_equal :create, assert_authorized_post(Url, params: hs2pass2.merge({url: "abc.x/invalid" }), diff_num: 0, err_msg: "should have failed due to the invalid URI, but Response is...").first

    ## Should create Domain and DomainTitle in this create Url
    new_dom = "very-new.com"
    path = "/ab.html?q=3"
    note3 = "note3"
    hs2pass3 = hs2pass.merge(title: "new 3 pass", url: new_dom+path, domain_id: "", note: note3)
    action, new_mdl3 = assert_authorized_post(Url, params: hs2pass3, diff_count_command: calc_count_exp, diff_num: 2111, updated_attrs: [:note]){ |user, record| # defined in /test/helpers/controller_helper.rb
      assert_equal new_dom, record.domain.domain
      assert_equal new_dom, record.domain_title.title
      assert_equal "new 3 pass", record.title
    }
    assert_equal :create, action

    ## Should create Domain but NOT DomainTitle
    path4 = "/ab.html?q=3&r=6"
    note4 = "note4"
    hs2pass4 = hs2pass.merge(title: "new 4 pass", url: "www."+new_dom+path4, domain_id: "", note: note4)
    action, new_mdl4 = assert_authorized_post(Url, params: hs2pass4, diff_count_command: calc_count_exp, diff_num: 1011, updated_attrs: {url: "https://www."+new_dom+path4, note: note4}){ |user, record| # defined in /test/helpers/controller_helper.rb
      assert_equal "www."+new_dom, record.domain.domain, "Domain prefix 'www'?"
      assert_equal new_mdl3.domain_title, record.domain_title
    }
    assert_equal :create, action

    ### update/patch

    hsupdate = @hs_base.merge( hs2add )  # No language-related fields

    ## standard update
    note3 = "aruyo3"
    action, _ = assert_authorized_post(new_mdl2, params: hsupdate.merge(note: note3), updated_attrs: [:note]) # defined in /test/helpers/controller_helper.rb
    assert_equal :update, action

    ## Should create Domain and DomainTitle in this update Url
    new_dom6 = "another-new.org"
    note6 = "note6"
    hsupd6 = @hs_base.merge( hs2add ).merge({url: "www."+new_dom6, domain_id: "", note: note6})  # No language-related fields
    action, _ = assert_authorized_post(new_mdl4, params: hsupd6, updated_attrs: {url: "https://www."+new_dom6, note: note6}, diff_count_command: calc_count_exp, diff_num: 1110){ |user, record| # defined in /test/helpers/controller_helper.rb
      assert_equal @moderator_ja, user, "sanity check" 
      assert record.domain
      assert_equal "www."+new_dom6, record.domain.domain, "Domain check..."
      assert_equal        new_dom6, record.domain_title.title, "www. should be removed from[ DomainTitle"
      assert_equal "https://www."+new_dom6, record.url, "sanity check"  # should have been already checked by assert_authorized_post()
    }
    assert_equal :update, action
    dt6 = new_mdl4.reload.domain_title

    ## Should create Domain but not DomainTitle in this update Url
    path7 = "/?q=345"
    note7 = "note7"
    hsupd7 = @hs_base.merge( hs2add ).merge({url: (url7=new_dom6+path7), domain_id: "", note: note7})  # No language-related fields
    action, _ = assert_authorized_post(new_mdl4, params: hsupd7, updated_attrs: {url: "https://"+url7, note: note7}, diff_count_command: calc_count_exp, diff_num: 10){ |user, record| # defined in /test/helpers/controller_helper.rb
      assert_equal @moderator_ja, user, "sanity check" 
      assert record.domain
      assert_equal new_dom6, record.domain.domain
      assert_equal new_dom6, record.domain_title.title
      assert_equal      dt6, record.domain_title
    }
    assert_equal :update, action

    sign_out @moderator_ja

    # User trans-editor (fails)

    note4 = "aruyo4"
    assert_equal :update, assert_unauthorized_post(new_mdl2, user: @translator, params: hsupdate.merge(note: note4), unchanged_attrs: [:note]) # defined in /test/helpers/controller_helper.rb

    ### destroy

    ## fail
    [nil, @translator].each do |ea_user|
      assert_equal :destroy, assert_unauthorized_post(new_mdl2, user: ea_user) # defined in /test/helpers/controller_helper.rb
    end

    ## success
    action, _ =assert_authorized_post(new_mdl2, user: @moderator_ja) # defined in /test/helpers/controller_helper.rb
    assert_equal :destroy, action

  end
end
