# coding: utf-8
require "test_helper"

class Artists::AnchoringsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  # path helpers
  include Rails.application.routes.url_helpers
  include BaseAnchorablesHelper  # for path_anchoring

  setup do
    @url = urls(:one)
    @artist = artists(:artist1)
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
      "title"=>"The Tｅst12",
    }.with_indifferent_access
    @hs_base = {
      url_form: "",  # mandatory
      url_langcode: "",
      #domain_id: "",  # mandatory at the model level but not in Controller
      weight: "",
      note: "",
      memo_editor: nil,
      site_category_id: @site_category.id.to_s,  # Default: ""
    }.with_indifferent_access
    #}.merge(
    #  %w(published_date last_confirmed_date).map{|ew|
    #    [1,2,3].map{|i| [sprintf("%s(%di)", ew, i), ""]}.to_h  # WARNING: nil instaed of "" would cause a weird Rails-level error of "undefined method `empty?'"
    #  }.inject({}){|i,j| i.merge j}
    #).with_indifferent_access
    ## NOTE: you may use: ApplicationHelper#get_params_from_date_time
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should create/update/destroy anchoring by moderator" do
    calc_count_exp = 'Anchoring.count*10000 + Translation.count*1000 + DomainTitle.count*100 + Domain.count*10 + Url.count'

    newurl = @domain.domain+"/newabc.html?q=123&r=456#anch"
    #hs2add = { url: newurl, domain_id: @domain.id.to_s, note: "test-create", memo_editor: "test-editor", weight: 111.24}
    #hs2pass = @hs_create_lang.merge(@hs_base).merge( hs2add )

    anchoring = anchorings(:artist1_wiki_en_artist1) #Anchoring.first
    art0 = anchoring.anchorable
    url0 = anchoring.url

    paths = {
      create:    artist_anchorings_path(artist_id: art0.id),
      new:   new_artist_anchoring_path(artist_id: art0.id),
      edit: edit_artist_anchoring_path(id: anchoring.id, artist_id: art0.id),
      show:      artist_anchoring_path(id: anchoring.id, artist_id: art0.id),
    }.with_indifferent_access
    proc_art0_path = Proc.new{artist_anchoring_path(id: Anchoring.last.id, artist_id: art0.id)}
    assert_equal paths[:show], artist_anchoring_path(anchoring, artist_id: art0.id)
    assert_raises(ActionController::UrlGenerationError){
      artist_anchoring_path(anchoring, "artist_id" => art0.id)}  # Basic unit test. How you specify the arguments is important!!

    hsprms = @hs_base.merge({
      # id: anchoring.id.to_s,
      artist_id: art0.id.to_s,
      url_form: newurl,
    })

    urlstr_orig = url0.url

    scat = site_categories(:site_category_media)
    hsupdate = hsprms.merge({id: anchoring.id.to_s, url_form: hsprms[:url_form]+"-updated"},
                             site_category_id: scat.id.to_s)  # No language-related fields
    refute_equal anchoring.site_category, SiteCategory.find(hsupdate[:site_category_id]), 'testing fixtures'

    ## standard update
    note3 = "aruyo3"
    action, mdl1 = assert_authorized_post(anchoring, user: @moderator_ja, path_or_action: paths[:show], redirected_to: path_anchoring(anchoring, action: :show), params: hsupdate, method: :patch, diff_count_command: calc_count_exp, diff_num: 0, updated_attrs: [:note]){ |user, record|  # path_anchoring() defined in Artists::AnchoringsHelper
      assert record.url
      refute_equal urlstr_orig, record.url.url
    } # defined in /test/helpers/controller_helper.rb
    assert_equal :update, action
    assert_equal scat, mdl1.reload.site_category
if false    
end # if false

    ## Public should not access edit etc.
    hs2pass5 = hsprms.merge({url_form: "https://naiyo.com/abc", note: "invisible5"})
    # [nil].each do |ea_user|  # @trans_moderator may be pviviledged?
    ## any editor can manage Artist, thus Artist/Anchoring
    _assert_login_demanded(paths[:new])
    _assert_login_demanded(paths[:edit])
    _assert_authorized_get_set(paths[:new], Anchoring, fail_users: [], success_users: [@editor_ja, @editor_harami], h1_title_regex: nil)

    _assert_authorized_get_set(paths[:edit],Anchoring, fail_users: [], success_users: [@editor_ja, @editor_harami], h1_title_regex: nil)

    # assert_equal :create, assert_unauthorized_post(Anchoring, user: nil, params: hs2pass5, path_or_action: paths[:create]) # defined in /test/helpers/controller_helper.rb
    # end

    sign_in @moderator_ja

    ## Successful creation of Anchoring and Url with existing Domain and DomainTitle
    action, new_mdl2 = assert_authorized_post(Anchoring, user: @moderator_ja, path_or_action: paths[:create], redirected_to: proc_art0_path, params: hsprms, method: :post, diff_count_command: calc_count_exp, diff_num: 11001){ |_, _| # defined in /test/helpers/controller_helper.rb
      assert_equal "https://"+newurl, Anchoring.last.url.url }
    assert_equal :create, action

    ## Successful creation of Anchoring and Url with NON-existing Domain and DomainTitle
    newurl3 = "abcd."+newurl+"777"
    note3   = "arunote3"
    hsprms3 = hsprms.merge({url_form: newurl3, note: note3, site_category_id: ""})  # SiteCategory auto-guessed.
    sccat = SiteCategory.find hsprms[:site_category_id]
    action, new_mdl3 = assert_authorized_post(Anchoring, user: @moderator_ja, path_or_action: paths[:create], redirected_to: proc_art0_path, params: hsprms3, method: :post, diff_count_command: calc_count_exp, diff_num: 12111, updated_attrs: %i(note)){ |_, record| # defined in /test/helpers/controller_helper.rb
      assert_equal "https://"+newurl3, record.url.url  # NOTE: url_form becomes nil after "reload"; hence you would either check it here in the yield block or include it in updated_attrs as a Hash like {url: nerurl3}
      assert_equal new_mdl2.site_category, record.site_category, "SiteCategory should agree because of auto-guess, but..."   # this should have been checked in updated_attrs
    }
    assert_equal :create, action


    ## Wikipedia URL addition
    wiki = "ja.wikipedia.org/wiki/%E5%B0%8F%E6%9E%97%E5%B9%B8%E5%AD%90#%E5%87%BA%E6%BC%94" # "/wiki/小林幸子#出演"
    hswiki = hsprms.merge({url_form: wiki, title: "", url_langcode: "", site_category_id: ""})
    action, new_mdl4 = assert_authorized_post(Anchoring, user: @moderator_ja, path_or_action: paths[:create], redirected_to: proc_art0_path, params: hswiki, method: :post, diff_count_command: calc_count_exp, diff_num: 11001){ |user, record| # defined in /test/helpers/controller_helper.rb
      assert_equal "https://"+wiki, record.url.url
      assert_equal "ja", record.url.orig_langcode.to_s
      trans = record.url.orig_translation
      assert_equal "小林幸子", trans.title
      assert_equal "ja",       trans.langcode
      assert_operator new_mdl3.created_at, :>, record.domain.created_at, "Existing Domain should have been identified, but..."
      assert_operator new_mdl3.created_at, :>, record.domain_title.created_at
    }
    assert_equal :create, action

#
#    assert_equal :create, assert_authorized_post(Url, params: hs2pass.merge({title: ""}), diff_num: 0, err_msg: "null title should not be allowed, but Response is...").first # defined in /test/helpers/controller_helper.rb
#
#    assert_equal :create, assert_authorized_post(Url, params: hs2pass2.merge({url: "abc.x/invalid" }), diff_num: 0, err_msg: "should have failed due to the invalid URI, but Response is...").first

    ### update/patch

#    [nil, @translator].each do |ea_user|  # @trans_moderator may be pviviledged?
#      assert_unauthorized_post(anchoring, user: ea_user, path_or_action: paths[:show], params: hsprms, method: :patch, diff_count_command: calc_count_exp){ |user, record|
#        assert_equal urlstr_orig, record.url.url
#      }
#    end

    # Edit
    sign_in @moderator_all
    get edit_artist_anchoring_path(id: new_mdl4.id, artist_id: new_mdl4.anchorable.id)
    assert_response :success, "User=#{@moderator_all} should be able to access #{path} but they are not..."
    # regex = %r@\A(/[a-z]{2})?/artists/#{new_mdl4.anchorable.id}/anchorings/#{new_mdl4.id}(\?.+)?\z@
    regex = %r@\A(/[a-z]{2})?/artists/(\d+)/anchorings/(\d+)(\?.+)?\z@
    assert_match(regex, attri=css_select("form.edit_anchoring")[0]["action"].to_s)
    match = regex.match attri
    assert_equal new_mdl4.id,            match[3].to_i, "second path-ID should be for Anchoring, but..."
    refute_equal new_mdl4.anchorable.id, match[3].to_i, "second path-ID should NOT be for Anchorable, but it is for the same as for Anchoring(!), i.e., the ID for Anchoring is used twice in the path: #{attri}"
    assert_equal new_mdl4.anchorable.id, match[2].to_i, "first path-ID should be for Anchorable, but..."
    sign_out @moderator_all


    # hsupdate = @hs_base.merge( hs2add )  # No language-related fields
    hsupdate = hsprms.merge({url_form: hsprms[:url_form]+"-updated"})  # No language-related fields

    ## standard update
    note3 = "aruyo3"
    action, _ = assert_authorized_post(anchoring, user: @moderator_ja, path_or_action: paths[:show], redirected_to: path_anchoring(anchoring, action: :show), params: hsupdate, method: :patch, diff_count_command: calc_count_exp, diff_num: 0, updated_attrs: [:note]){ |user, record|  # path_anchoring() defined in Artists::AnchoringsHelper
      assert record.url
      refute_equal urlstr_orig, record.url.url
    } # defined in /test/helpers/controller_helper.rb
    assert_equal :update, action

    url_orig = anchoring.url.url
    action, _ = assert_authorized_post(anchoring, user: @moderator_ja, path_or_action: paths[:show], redirected_to: path_anchoring(anchoring, action: :show), params: hsupdate.merge({url_form: ""}), method: :patch, diff_count_command: calc_count_exp, diff_num: 0, updated_attrs: [:note], exp_response: :unprocessable_content){ |user, record|  # path_anchoring() defined in Artists::AnchoringsHelper
      assert record.url
      assert_equal url_orig, record.url.url
    } # defined in /test/helpers/controller_helper.rb
    assert_equal :update, action

  end
end
