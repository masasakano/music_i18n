# coding: utf-8
require "test_helper"
require "helpers/controller_anchorable_helper"

class Events::AnchoringsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::TestCase::ControllerAnchorableHelper
  
  # add this
  include Devise::Test::IntegrationHelpers

  # path helpers
  include Rails.application.routes.url_helpers
  include BaseAnchorablesHelper  # for path_anchoring

  setup do
    @url = urls(:one)
    @event = events(:three)
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
    # defined in /test/helpers/controller_anchorable_helper.rb
    opt_users = {fail_users: [], success_users: [@moderator_all]}
    news = _assert_create_anchoring_urls_domains(@event, **opt_users)
    new1 = news.first
    new2 = _assert_create_anchoring_url_wiki(   @event, **opt_users)

    _refute_public_accesses_to_anchorables(new1)
    _assert_authorized_gets_to_anchorables(new1, **opt_users)  # :new, :edit : disallowed

    calc_count_exp = 'Anchoring.count*10000 + Translation.count*1000 + DomainTitle.count*100 + Domain.count*10 + Url.count'

    newurl = @domain.domain+"/newabc.html?q=123&r=456#anch"
    #hs2add = { url: newurl, domain_id: @domain.id.to_s, note: "test-create", memo_editor: "test-editor", weight: 111.24}
    #hs2pass = @hs_create_lang.merge(@hs_base).merge( hs2add )

    anchoring = Anchoring.first
    art0 = anchoring.anchorable
    url0 = anchoring.url

    paths = {
      create:    event_anchorings_path(event_id: @event.id),
      new:   new_event_anchoring_path( event_id: @event.id),
      # edit: edit_event_anchoring_path(id: anchoring.id, event_id: @event.id),
      # show:      event_anchoring_path(id: anchoring.id, event_id: @event.id),
    }.with_indifferent_access
    proc_art0_path = Proc.new{event_anchoring_path(id: Anchoring.last.id, event_id: @event.id)}  ############ ????

    hsprms = @hs_base.merge({
      # id: anchoring.id.to_s,
      event_id: art0.id.to_s,
      url_form: newurl,
    })

    urlstr_orig = url0.url

    scat = site_categories(:site_category_media)
    hsupdate = hsprms.merge({id: anchoring.id.to_s, url_form: hsprms[:url_form]+"-updated"},
                             site_category_id: scat.id.to_s)  # No language-related fields
    refute_equal anchoring.site_category, SiteCategory.find(hsupdate[:site_category_id]), 'testing fixtures'

if false    
end # if false

    ## Public should not access edit etc.
    hs2pass5 = hsprms.merge({url_form: "https://naiyo.com/abc", note: "invisible5"})
    # [nil].each do |ea_user|  # @trans_moderator may be pviviledged?
    ## any editor can manage Event, thus Event/Anchoring

    sign_in @moderator_ja

    ## Successful creation of Anchoring and Url with existing Domain and DomainTitle
    action, new_mdl2 = assert_authorized_post(Anchoring, user: @moderator_ja, path_or_action: paths[:create], redirected_to: proc_art0_path, params: hsprms, method: :post, diff_count_command: calc_count_exp, diff_num: 11001){ |_, _| # defined in /test/helpers/controller_helper.rb
      assert_equal "https://"+newurl, Anchoring.last.url.url }
    assert_equal :create, action

    ## Chronicle URL addition
    chronicle = "https://nannohi-db.blog.jp/archives/8522599.html"
    hschronicle = hsprms.merge({url_form: chronicle, title: "", url_langcode: "", site_category_id: ""})
    action, new_mdl5 = assert_authorized_post(Anchoring, user: @moderator_ja, path_or_action: paths[:create], redirected_to: proc_art0_path, params: hschronicle, method: :post, diff_count_command: calc_count_exp, diff_num: 11001){ |user, record| # defined in /test/helpers/controller_helper.rb
      assert_equal chronicle, record.url.url
      assert_equal "ja",      record.url.url_langcode.to_s
      sc = site_categories(:site_category_chronicle)
      assert_equal sc,        record.site_category
      # trans = record.url.orig_translation
      # assert_equal "ハラミちゃんが表紙の「月刊ショパン5月号」発売", trans.title
      # assert_equal "ja",       trans.langcode
      assert_operator new_mdl2.created_at, :>, record.domain.created_at, "Existing Domain should have been identified, but..."
      assert_operator new_mdl2.created_at, :>, record.domain_title.created_at
    }
    assert_equal :create, action


    ### update/patch

#    [nil, @translator].each do |ea_user|  # @trans_moderator may be pviviledged?
#      assert_unauthorized_post(anchoring, user: ea_user, path_or_action: paths[:show], params: hsprms, method: :patch, diff_count_command: calc_count_exp){ |user, record|
#        assert_equal urlstr_orig, record.url.url
#      }
#    end

    ## hsupdate = @hs_base.merge( hs2add )  # No language-related fields
    #hsupdate = hsprms.merge({url_form: hsprms[:url_form]+"-updated"})  # No language-related fields
    new_mdl4 = news.last
    hsupdate = _build_params(new_mdl4, url_form: (urlstr_orig=new_mdl4.url.url)+"-updated", note: (note4 = "upd4"))

    ## standard update
    path4 = event_anchoring_path(id: new_mdl4.id, event_id: new_mdl4.anchorable.id)
    #note4 = "upd4"
    action, _ = assert_authorized_post(new_mdl4, user: @moderator_ja, path_or_action: path4, redirected_to: path_anchoring(new_mdl4, action: :show), params: hsupdate, method: :patch, diff_count_command: calc_count_exp, diff_num: 0, updated_attrs: [:note]){ |user, record|  # path_anchoring() defined in Artists::AnchoringsHelper
      assert record.url
      if urlstr_orig.nil?
        refute_nil record.url.url
      else
        refute_equal urlstr_orig, record.url.url
      end
      assert_equal note4, record.note, "updated Anchoring: #{record.inspect} / #{record.url.inspect} / #{record.url.url.inspect}"
    } # defined in /test/helpers/controller_helper.rb
    assert_equal :update, action

  end
end
