# coding: utf-8
require "test_helper"
require "helpers/controller_anchorable_helper"

class Musics::AnchoringsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::TestCase::ControllerAnchorableHelper
  
  # add this
  include Devise::Test::IntegrationHelpers

  # path helpers
  include Rails.application.routes.url_helpers
  include BaseAnchorablesHelper  # for path_anchoring

  setup do
    @url = urls(:one)
    @anchorable = @music = musics(:music1)
    @anchorabl2 = musics(:music2)
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
    opt_users = {fail_users: [], success_users: [@moderator_all]}  # only a single success_users is valid for :create, whereas multiple fail_users can be tested.
    ## access to parent's show and anchoring's new
    _assert_authorized_get_to_parent(@anchorable, **opt_users)
    n_asserts = _assert_authorized_gets_to_anchorables(@anchorable, **opt_users)
    assert_equal 1*(opt_users[:fail_users].size + opt_users[:success_users].size), n_asserts, "#{_get_caller_info_message(prefix: true)} sanity check failed; should have assesed access to :new only, but..."

    ancs = new_anchorings = _assert_create_anchoring_urls_domains(@anchorable, **opt_users)  # defined in controller_anchorable_helper.rb
    ancs[0] = new_anchorings.first

    ## access to new/edit
    n_asserts = _assert_authorized_gets_to_anchorables(ancs[0], **opt_users)
    assert_equal 2*(opt_users[:fail_users].size + opt_users[:success_users].size), n_asserts, "#{_get_caller_info_message(prefix: true)} sanity check failed; should have assesed access to :new and :edit, but..."

    # Attempting to create an identical Anchoring 
    sc_media = site_categories(:site_category_media)  # trying a different SiteCategory
    res = _refute_create_identical_anchoring( ancs[0], title: "unique new4 title", site_category_id: sc_media.id.to_s, **opt_users)  # testing failed creation, redirection etc.
    flash_regex_assert(/\bis already registered\b/, "Identical Anchoring should fail... ", type: :alert, category: :all, is_debug: false) # defined in test_helper.rb  # error message defined in :create in base_anchorables_controller.rb

    # Creating a Url and Artist-Anchoring
    this_classname = @anchorable.class.name
    artist_anc = nil
    artist = artists(:artist1)
    fmt = "Anchoring.where(anchorable_type: '%s').count"
    assert_no_difference(sprintf(fmt, this_classname)){
      assert_difference( sprintf(fmt, 'Artist')+' + Url.count*10 + Translation.count*100', 111){
        artist_anc = _assert_create_anchoring_url_wiki( artist, **opt_users)
      }
    }

    # Creating an Event-Anchoring for the SAME Url as with Artist - should succeed.
    note4 = "anc-only-4"
    fmt = sprintf("Anchoring.where(anchorable_type: '%%s', url_id: %d).count", artist_anc.url.id)
    assert_difference(sprintf(fmt, this_classname)){
      assert_no_difference( sprintf(fmt, 'Artist')){
        ancs << _assert_create_anchoring_existing_url(artist_anc, @anchorable, note: note4, is_debug: false, **opt_users)
      }
    }

    # The same but with another Event
    note5 = "anc-only-5"
    assert_difference(sprintf(fmt, this_classname)){
      ancs << _assert_create_anchoring_existing_url(artist_anc, @anchorabl2, note: note5, **opt_users)
    }

    ## Anotehr Wikipedia URL creation
    wiki = "https://ja.wikipedia.org/wiki/清塚信也"
    ancs << _assert_create_anchoring_url_wiki(@anchorable, url_wiki: wiki, wiki_name: "清塚信也", **opt_users)
    assert ancs[-1].is_a?(Anchoring)

    ## Access Forbidden
    _refute_public_accesses_to_anchorables(ancs[0])
    _assert_authorized_gets_to_anchorables(ancs[0], **opt_users)  # :new, :edit : disallowed

    ## Chronicle URL addition
    ancs << _assert_create_anchoring_url_chronicle(@anchorable, **opt_users)
    assert ancs[-1].is_a?(Anchoring)
   

    ### update/patch

    note7 = "upd-7"
    newurl = (origurl=ancs[0].url.url)+"-updated0"
    ancs << _assert_update_anchoring_url(ancs[0], url_str: newurl, note: note7, **opt_users)
    assert_equal ancs[0].id, ancs[-1].id
    assert_equal newurl,     ancs[-1].url.url
    assert_equal note7,      ancs[-1].note

    ## Attempting to chante the url to an existing one => should fail.
    note8 = "upd-8"
    tmpurl = ancs[2].url.url  # should conflict
    upd = ancs[0].updated_at
    pid = ancs[0].id
    ancs << _assert_update_anchoring_url(ancs[0], url_str: tmpurl, note: note8, exp_response: :unprocessable_entity, **opt_users)
    assert_equal ancs[0].id, ancs[-1].id
    assert_equal newurl,     ancs[-1].reload.url.url
    assert_equal pid,        ancs[-1].id
    assert_equal upd,        ancs[-1].reload.updated_at
    refute_equal note8,      ancs[-1].note

#    [nil, @translator].each do |ea_user|  # @trans_moderator may be pviviledged?
#      assert_unauthorized_post(anchoring, user: ea_user, path_or_action: paths[:show], params: hsprms, method: :patch, diff_count_command: EQUATION_MODEL_COUNT){ |user, record|
#        assert_equal urlstr_orig, record.url.url
#      }
#    end

  end
end
