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
    @anchorable = @event = events(:three)
    @anchorabl2 = events(:ev_harami_lucky2023)
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

    #str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
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
    _ = _refute_create_identical_anchoring( ancs[0], title: "unique new4 title", site_category_id: sc_media.id.to_s, **opt_users)  # testing failed creation, redirection etc.
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


    ##### Event-Anchoring-specific tests! (not because unique to Event-specific, but to avoid repeated tests)
    ####opt_users = {fail_users: [], success_users: [@moderator_all]}  # only a single success_users is valid for :create, whereas multiple fail_users can be tested.
    url_unk = Url.unknown
    url_unk.update!(url: url_unk.url.sub(/^https/, "http"))  # "http://example.com" actually responds, but "https" does not.
    url_unk_http_orig = url_unk.url
    tit_orig = url_unk.title

    assert_equal "http://", url_unk.url[0,7], "test fixtures (which are actually seeds)"
    refute_includes @anchorable.urls, url_unk, "sanity check (of fixtures)"
    refute_includes        url_unk.translations.pluck(:title), "Example Domain", 'tests fixtures'
    assert_operator 1, :<, url_unk.translations.count, 'tests fixtures'
    css_checkbox = "#anchoring_fetch_h1"

    ## Preparation - destroying most Translations but one from the Url (Url.unknown)
    url_unk.translations.find_by(langcode: "ja").destroy
    url_unk.translations.reset
    Translation.sort(url_unk.translations).reverse[1..-1].each do |etra|
      etra.destroy!
    end
    url_unk.translations.reset
    assert_equal 1, url_unk.translations.count, "sanity check: #{url_unk.translations.inspect}"
    url_unk.translations.first.update!(langcode: "pt")
    url_unk.translations.reset
    assert_equal ["pt"], url_unk.translations.pluck(:langcode).flatten

    ## First Anchoring creation for an existing Url succeeds, but fetch_h1 must be ignored for an existing Url.
    #
    # :new screen
    _assert_authorized_gets_to_anchorables(@anchorable, methods: %i(new), fail_users: [], success_users: [@sysadmin]){
      nodes = css_select(css_checkbox)
      assert  nodes.present?  # The option should be provided on the form.
      assert_equal 1, nodes.size, "fetch_h1 checkbox now should appear and be checked in :new"
      assert is_checkbox_checked?(nodes[0])  # defined in test_helper.rb
    }

    # :create => succeed
    anchoring = @anchorable.anchorings.find_by(url_id: url_unk.id)
    note9 = "note9"
    anc9 = _assert_create_anchoring_url_core( @anchorable,
              fail_users: [], success_users: [@sysadmin],  # because accessing Url.unknown
              diff_num: 1,
              url_str: url_unk_http_orig,  note: note9,
              fetch_h1: "1",  # Suppose the user sets this so.
            )

    refute       anc9.new_record?
    assert_equal url_unk, anc9.url
    assert_equal note9,   anc9.note
    url_unk.reload
    assert_equal url_unk_http_orig, url_unk.url
    assert_equal tit_orig,          url_unk.title, 'should have not changed, but...'

    ## Url/Anchoring update with fetch_h1 succeeds for the Url with a single Translations.
    #
    # :edit screen
    _assert_authorized_gets_to_anchorables(anc9, methods: %i(edit), fail_users: [], success_users: [@sysadmin]){ |user, curpath|
      nodes = css_select(css_checkbox)
      assert  nodes.present?  # The option should be provided on the form.
      assert_equal 1, nodes.size, "fetch_h1 checkbox now should appear though it should be uncheced on access to :edit always"
      refute is_checkbox_checked?(nodes[0])  # In :edit, fetch_h1 checkbox is unchecked in default.  # defined in test_helper.rb
    }

    # :update -> success
    refute anc9.new_record?, 'sanity check'
    note10 = "note10"
    anca = _assert_create_anchoring_url_core( anc9,
              is_create: false, fail_users: [], success_users: [@sysadmin],  # because accessing Url.unknown
              diff_num: 0,
              url_str: url_unk_http_orig,  note: note10,
              fetch_h1: "1") # Suppose the user sets this so.

    assert_equal anca,   anc9, "sanity check"
    assert_equal note10, anc9.note, "updated?"
    url_unk.reload
    assert_equal 1, url_unk.translations.count
    tra = url_unk.translations.first
    refute_equal tit_orig,         tra.title, 'should have changed, but...'
    assert_equal "Example Domain", tra.title, 'should have been updated to this, fetched H1, but...'
    assert_equal "pt",             tra.langcode, 'langcode should remain, but...'

    ## Another Preparation - adding a Translation to Url (Url.unknown)
    assert_includes  url_unk.translations.pluck(:title), "Example Domain", "should have one"
    url_unk.translations.first.update!(title: "back-to-original")
    url_unk.translations << Translation.new(title: "dummy10", langcode: "fr", is_orig: false)
    url_unk.translations.reset
    assert_equal 2, url_unk.translations.count, 'sanity check'
    refute_includes  url_unk.translations.pluck(:title), "Example Domain", "should NOT have one"

    #  Then, the attempt of updating with fetch_h1 should fail, because Url has multiple Translations.
    #
    # :edit screen
    _assert_authorized_gets_to_anchorables(anc9, methods: %i(edit), fail_users: [], success_users: [@sysadmin]){
      assert css_select(css_checkbox).blank?, 'The checkbox should not be provided on the form in the first place, but...'
    }

    # :update -> fail
    note11 = "note11"
    ancb = _assert_create_anchoring_url_core( anc9,
              is_create: false, fail_users: [], success_users: [@sysadmin],  # because accessing Url.unknown
              diff_num: 0,
              url_str: url_unk_http_orig,  note: note11,
              fetch_h1: "1",  # Suppose the user sets this so.
              exp_response: :unprocessable_entity
            )

    assert_equal ancb,   anc9, "sanity check"
    refute_equal note11, anc9.note, "not updated?"
    url_unk.reload
    refute_includes  url_unk.translations.pluck(:title), "Example Domain", "should not updated."

    refute_equal tit_orig,         url_unk.title, 'should have changed, but...'
    refute_equal "Example Domain", url_unk.title, 'should have been updated to this, fetched H1, but...'
    refute_includes  url_unk.translations.pluck(:title), "Example Domain", "not included in any of Translatons, but..."


#    [nil, @translator].each do |ea_user|  # @trans_moderator may be pviviledged?
#      assert_unauthorized_post(anchoring, user: ea_user, path_or_action: paths[:show], params: hsprms, method: :patch, diff_count_command: EQUATION_MODEL_COUNT){ |user, record|
#        assert_equal urlstr_orig, record.url.url
#      }
#    end

  end
end
