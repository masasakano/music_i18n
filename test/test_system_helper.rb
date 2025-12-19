# coding: utf-8
require "test_helper"

# @example Already required in test_helper
#
class ActiveSupport::TestCase

  CSSQUERIES ||= {}.with_indifferent_access
  CSSQUERIES[:error_div] ||= {}.with_indifferent_access
  CSSQUERIES[:error_div][:whole] = 'div#error_explanation'
  CSSQUERIES[:error_div][:title] = CSSQUERIES[:error_div][:whole]+" h2"
  CSSQUERIES[:hidden] ||= {}.with_indifferent_access
  CSSQUERIES[:hidden][:prefecture] = 'form div#'+ApplicationController::HTML_KEYS[:ids][:div_sel_prefecture]+' div.form-group'
  CSSQUERIES[:hidden][:place]      = 'form div#'+ApplicationController::HTML_KEYS[:ids][:div_sel_place]+     ' div.form-group'
    # e.g., assert_selector ActiveSupport::TestCase::CSSQUERIES[:hidden][:place], visible: :hidden
    #       assert_no_selector ActiveSupport::TestCase::CSSQUERIES[:hidden][:place] # display: none
    #       assert_empty page.find_all(:xpath, "//form//div[@id='#{ApplicationController::HTML_KEYS[:ids][:div_sel_place]}']//div[contains(@class, 'form-group')][contains(@style,'display: none;')]")
    # c.f., in the old-school FORM:  assert_selector 'form div#div_select_place', visible: :hidden

  CSSQUERIES[:trans_new] ||= {}.with_indifferent_access
  # Note: for the old-style Rails form: page.find('form div.field.radio_langcode')
  %w(langcode is_orig).each do |es|
    CSSQUERIES[:trans_new][es+"_radio"] = "form fieldset.%s_"+ApplicationController::PARAMS_NAMES[:trans][es].to_s # NOTE: requires model-name!!
    # e.g., 'form fieldset.%s_langcode'
    #       'form fieldset.%s_best_translation_is_orig'
  end

  TEXT_ASSERTED ||= {}.with_indifferent_access
  TEXT_ASSERTED[:login] ||= {}.with_indifferent_access
  TEXT_ASSERTED[:login][:signed_in] = TEXT_ASSERTED[:login][:logged_in] = "Signed in successfully."
  TEXT_ASSERTED[:login][:signed_in_fail] = TEXT_ASSERTED[:login][:logged_in_fail] = "Invalid Email or password."
  TEXT_ASSERTED[:login][:signed_out] = TEXT_ASSERTED[:login][:logged_out] = "Signed out successfully."
  TEXT_ASSERTED[:login][:need] = "You need to sign in or sign up"

  # Temporarily sets a longe wait time for the specific block (in case the machine is slow)
  #
  # To activate it, either specify the time directly or set +ENV["CAPYBARA_LONGER_TIMEOUT"]+ set with an Integer in second.
  # Then, when the environmental variable is not set (the machine is not slow), 
  # none of these blocks would wait too long.
  #
  # @example
  #   with_longer_wait{ assert_selector 'section#mypart div.error_explanation'}
  #   # defined in test_system_helper.rb ; use with CAPYBARA_LONGER_TIMEOUT=3
  #
  def with_longer_wait(ti=ENV["CAPYBARA_LONGER_TIMEOUT"])
    if ti.present?
      Capybara.using_wait_time(ti.to_i){ yield }
    else
      yield
    end
  end

  # Capybara save_page in system tests with filaneme information automatically assigned, and info printed
  #
  # @example
  #   save_page_auto_fname  # defined in test_system_helper.rb
  def save_page_auto_fname(with_time: false)
    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf("%s-L%d", bind.absolute_path.sub(%r@.*(/test/system/)@, ""), bind.lineno)  # may contain "/", which should be replaced!
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    time_str = "-"+Time.now.strftime("%Y%m%d%H%M%S") if with_time
    fname = sprintf("page%s-%s.html", time_str, caller_info).gsub(%r@/@, "_")
    page.save_page(fname)
    
    puts sprintf("Capybara HTML page saved at %s/%s", Capybara.save_path, fname)
  end


  # @example Controller test
  #   assert_empty css_select(css_query(:trans_new, :is_orig_radio, model: Model))  # defined in test_system_helper
  # 
  # @example System test
  #   assert_no_selector css_query(:trans_new, :is_orig_radio, model: Prefecture)
  def css_query(key1, key2=nil, model: nil)
    query = CSSQUERIES[key1]
    query = query[key2] if key2.present?
    query = sprintf(query, get_modelname(model)) if model  # defined in application_helper.rb
    raise "no query for [key1, key2]=#{[key1, key2].inspect}" if !query
    query
  end 

  # @example
  #   assert_match(/ prohibited /, page_find_sys(:error_div, :title).text)  # defined in test_system_helper
  #   page_find_sys(:trans_new, :langcode_radio, model: MyModel).choose('English')  # defined in test_system_helper
  #    Old forms: page.find('form div.field.radio_langcode').choose('English')
  #   page_find_sys(:trans_new, :is_orig_radio, model: @channel_type).choose('No')  # defined in test_system_helper
  # 
  def page_find_sys(*args, **kwds)
    page.find(css_query(*args, **kwds))
  end 

  # Gets a field value, like a radio-button etc.
  #
  # @example Get a value for radio-buttons for "is_orig" in Page "new" for MyModel (e.g., ChannelType)
  #   assert_equal "on",   page_get_val(:trans_new, :is_orig, model: "my_model"), "is_orig should be Undefined, but..."  # defined in test_system_helper
  #   assert_equal "true", page_get_val(:trans_new, :is_orig, model:  my_model),  "is_orig should be true, but..."
  #
  # @example
  #   assert_equal "en",   page_get_val(:trans_new, :langcode, model: MyModel), "Language should be set English, but..."
  #
  def page_get_val(key1, key2=nil, model: nil)
    if "trans_new" == key1.to_s
      case key2.to_s
      when "langcode", "is_orig"
        page.find_field(name: get_modelname(model)+"[#{ApplicationController::PARAMS_NAMES[:trans][key2]}]", checked: true)["value"]  # defined in application_helper.rb
        # e.g., page.find_field(name: "channel_type[best_translation_is_orig]", checked: true)["value"]
      else
        raise "Unsupported, yet..."
      end
    else
        raise "Unsupported, yet..."
    end
  end 

  # Switch to :ja or :en in system tests, waiting for the page to be loaded.
  def switch_to_lang(langarg=nil, langcode: nil)
    langcode = (langarg || langcode)
    raise ArgumentError, "debug="+[langarg, langcode].inspect if !langcode
    csslinks = %i(en ja).map{ [_1, CSSHS[:language_switch_link_top][_1]+" a"] }.to_h.with_indifferent_access

    case langcode.to_sym
    when :ja
      assert_equal "日本語",  page.find(csslinks[:ja]).text
      refute_selector         csslinks[:en]
      page.find(csslinks[:ja]).click
      assert_selector         csslinks[:en]
      refute_selector         csslinks[:ja]
      assert_equal "English", page.find(csslinks[:en]).text
    when :en
      assert_equal "English", page.find(csslinks[:en]).text
      refute_selector         csslinks[:ja]
      page.find(csslinks[:en]).click
      assert_selector         csslinks[:ja]
      refute_selector         csslinks[:en]
      assert_equal "日本語",  page.find(csslinks[:ja]).text
    else
      raise "contact the code developer"
    end
  end

  # Returns a Hash of Arrays of title-s and alt_title-s in the translation table in Show etc.
  #
  # @example
  #    assert_includes trans_titles_in_table(langcode: "en", fallback: true).values.flatten.map(&:downcase), "My own title".downcase  # defined in test_system_helper.rb
  #
  # @param model [Class<ActiveRecord>, String, NilClass] model name, e.g., "harami_vid"
  # @param langcode [String, NilClass, Symbol] langcode (locale). If nil, all languages.
  # @param fallback [Boolean] If true (Def) and if langcode is specified, yet if no significant results are found, the results for all languages are returned.
  # @return [Hash<String => Array>] String of either title or alt_title (in this order for keys) (with_indifferent_access)
  def trans_titles_in_table(model: nil, langcode: nil, fallback: true)
    css_lang = (langcode.present? ? ".lc_#{langcode}" : "")

    model_singular = 
      if model.respond_to?(:name)
        model.name.underscore
      elsif model.blank?
        m = %r@^/?(?:[a-z]{2}/)?([a-z0-9_]{3,})@.match( page.current_path )
        if !m
          Rails.logger.error "ERROR(#{File.basename __FILE__}:#{__method__}): failed to guess the model-name, so the CSS cannot be constructed..."
          return css_lang
        else
          m[1].singularize
        end
      else
        model.to_s.underscore.singularize
      end

    hscss = {title: [], alt_title: []}
    basecss_tr = "section#sec_primary_trans table#all_registered_translations_#{model_singular} tbody tr.trans_row"+css_lang
    hscss[:title]     = find_all(basecss_tr+" td.trans_title").to_a
    hscss[:alt_title] = find_all(basecss_tr+" td.trans_alt_title").to_a
    if langcode.present? && fallback && %i(title alt_title).all?{|i| hscss[i].empty?}
      return send(__method__, langcode: nil)
    end
    hscss = hscss.map{|k, v| [k, v.map(&:text).map(&:strip)]}.to_h
    hscss[:alt_title].map!{|et| et.sub!(/(\s*\[.*\|.*\])?\z/, '')}
    hscss.with_indifferent_access
  end

  # Fill in a title (or romaji etc) in Model#new in a System test.
  #
  # @example
  #    fill_in_new_title_with(Music, "Song of Love", kind: "title", locale: "ja")  # defined in test_system_helper.rb
  #
  # @param model [Class, String] e.g., Music
  # @param title_str [String] "My glorious piece"
  # @param kind: [String] "title" (Def), "alt_title", "romaji" etc.
  def fill_in_new_title_with(model, title_str, kind: "title", locale: I18n.locale)
    opts = { model: (model.respond_to?(:name) ? model.name : model.to_s) }
    opts[:locale] = locale if I18n.locale
    label_str = I18n.t('layouts.new_translations.'+kind.to_s, **opts)
    find_field(label_str, match: :first).fill_in with: title_str
  end

  # logon in a system test
  def logon_system_test(user)
  end

  # @example
  #    login_at_root_path(@editor_ja)  # defined in test_system_helper.rb
  #
  # @example
  #    visit new_event_item_url  # direct jump -> fail
  #    refute_text "New EventItem"
  #    assert_text "You need to sign in or sign up"
  #    login_at_root_path(@moderator_all, with_visit: false, new_h1: "New EventItem")
  #
  # @param with_visit: [Boolean] if true (Def), this method visit the new_user_session page
  # @param new_h1: [String, NilClass] if with_visit is false, this is mandatory! H1 text after login.
  def login_at_root_path(user=@editor_harami, with_visit: true, new_h1: nil)
    if with_visit
      visit new_user_session_path 
      assert_selector "h2", text: "Log in"
    end
    fill_in "Email", with: user.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: (new_h1 || "HARAMIchan")
  end

  # performs log on
  #
  # @param succeed: [Boolean] if true (Default), should sign in successfully.
  def login_or_fail_index(user, succeed: true)
    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: user.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    exp = TEXT_ASSERTED[:login][(succeed ? :signed_in : :signed_in_fail)]
    assert_selector "body div.alert", text: exp
  end

  # performs log out
  #
  # @example
  #   logout_from_menu # defined in test_system_helper.rb
  def logout_from_menu
    assert page.find(:xpath, "//div[@id='navbar_top']//a[text()='Log out']").click
    assert_selector :xpath, xpath_for_flash(:notice, category: :div), text: TEXT_ASSERTED[:login][:signed_out]  # Notice message issued.
                          # "//div[@id='body_main']/p[contains(@class, 'notice')][1]" (and more)
    # assert_equal "Signed out successfully.", page.find(:xpath, xpath_for_flash(:notice, category: :div)).text.strip  # Notice message issued.
  end

  # Tests CRUD of Anchoring in Show page
  #
  # When returning, User user_succeed is signed in and in the page of Show.
  #
  # NOTE: this method should NOT be called twice within a method.
  #
  # @example
  #   assert_anchoring_crud_in_show(@artist, h1_title=nil)  # defined in test_system_helper.rb
  #
  # @example
  #   assert_anchoring_crud_in_show(@artist, skip_login: true)  # defined in test_system_helper.rb
  #
  # @param record [ActiveRecord] a Model record (n.b., String for the Show path is NOT accepted.)
  # @param h1_title [String, NilClass] h1 title string of the page (Model-index?) after successful login. If nil and if user_succeed is non-nil, it is guessed from the model, assuming the first argument is a model (NOT the path String).
  # @param user_fail: [User, NilClass] who fails to see the index page. if nil, the non-authorized user.
  # @param user_user_succeed: [User, NilClass] who succcessfully sees the index page
  # @param skip_login: [Boolean] If false (Def), call {#assert_index_fail_succeed}. If true, the caller must have signed in before the call.
  # @param skip_visit: [Boolean] Relevant only if `skip_login=true`. If false (Def), this method visits Show page. If true, the caller must have visited the page before the call.
  def assert_anchoring_crud_in_show(record, h1_title = nil, skip_login: false, skip_visit: false, user_fail: nil, user_succeed: nil, locale: nil)
    create_anchoring_button_txt = "Create Anchoring"
    raise ArgumentError, "user_fail not yet supported... Sorry! " if user_fail
    raise ArgumentError, "user_succeed not yet supported... Sorry! " if user_succeed

    skip_visit = false if !skip_login
    # if !record.respond_to?(:save!)
    #   path2visit = record
    # elsif !skip_login || !skip_visit
    path2visit = Rails.application.routes.url_helpers.polymorphic_path(record, locale: locale)  # without locale! :show should not be given!
    # end

    unless skip_visit
      visit path2visit
      h1_title ||= record.title(langcode: locale)
      assert_selector "h1", text: h1_title
      assert_selector "h3", text: I18n.t(:external_link, locale: locale).capitalize.pluralize(locale)  # "Anchorings"
      assert_empty page.find_all(:xpath, XPATHS[:anchoring][:item]), "xpath="+XPATHS[:anchoring][:item]  # No Anchoring (yet); defined in test_helper.rb
    end

    find(:xpath, XPATHS[:anchoring][:new_link]).click
    css_submit_anchoring = "input[value='#{create_anchoring_button_txt}']"
    # <input type="submit" name="commit" value="Create Anchoring" data-disable-with="Create Anchoring">
    assert_selector css_submit_anchoring
    xpath_item = XPATHS[:anchoring][:item] # defined in test_helper.rb
    refute_selector :xpath, xpath_item, wait: 0  # 0 Anchoring

    ## Create Url and Anchoring
    anchor_url = "https://example.com/"+record.class.name
    fill_in "URL", with: anchor_url
    select "Other", from: "Site category"
    fill_in "Description", with: (url_tit="my test description 2")
    uncheck "Tick this to update the title with H1 on the remote URL"
    click_on create_anchoring_button_txt
    refute_selector css_submit_anchoring

    record.anchorings.reset
    assert_equal 1, record.anchorings.count

    cssid_section = "anchoring_index_#{record.class.name}"
    xpath_section = "##{cssid_section} ul li a"
    assert_selector xpath_section  # Anchoring should have appeared

    ## Edit Anchoring
    assert_selector xpath_section  # Anchoring should have appeared
    assert_equal 1, find_all(:xpath, XPATHS[:anchoring][:item]).size  # 1 Anchoring; defined in test_helper.rb

    find(:xpath, XPATHS[:anchoring][:edit_button]).click
    xpath_textarea = XPATHS[:anchoring][:form_edit] + "//textarea[@id='anchoring_note']"
    assert_selector :xpath, xpath_textarea
    note_try = "my-anchoring-note-123"
    find(:xpath, xpath_textarea).fill_in with: note_try

    ## Update Anchoring
    click_on "Update Anchoring"
    refute_selector :xpath, xpath_textarea  # form should have disappeared
    assert_equal 1, find_all(:xpath, xpath_item).size  # 1 Anchoring remains; defined in test_helper.rb
    assert_includes find(:xpath, xpath_item).text, note_try  # The (edited) added "note" should appear.

    ## Attempt to Create Url and Anchoring identical to an (=the) existing Anchoring
    find(:xpath, XPATHS[:anchoring][:new_link]).click
    assert_selector css_submit_anchoring

    fill_in "URL", with: anchor_url
    click_on create_anchoring_button_txt

    refute_selector :xpath, css_submit_anchoring
    assert_selector :xpath, xpath_for_flash(:alert, category: :div, xpath_head: "//form[@id='form_new_anchoring']//"), text: "eview the problem", wait: 2  # defined in test_helper.rb
    # "Please review the problems below:"  (SimpleForm default)
    assert_selector('input[type="submit"][value="'+create_anchoring_button_txt+'"]:not([disabled])')
    assert_selector "div.invalid-feedback", text: test_msg=" is already registered"  # should be displayed below the URL form field (SimpleForm)
    #  Url form https://... is already registered. The submitted information is not used to update the URL except for association Note.

    click_on "Cancel"
    refute_text test_msg

    # Visiting Url#show
    xpath = "//*[@id='#{cssid_section}']//ul//li//a[contains(.,'Link-info')]"
    #   <a title="Internal Url-Show page" href="/en/urls/56">Link-info</a>
    turbo_id = dom_id(record)+"_anchorings"
    assert_selector :xpath, "//*[@id='#{cssid_section}']//turbo-frame[@id='#{turbo_id}']"

    assert_selector "##{turbo_id}", text: "Link-info", wait: 5
    within "#"+turbo_id do
      assert_text "Link-info"
      assert_selector :xpath, xpath
    end
    assert_equal "false", find(:xpath, xpath)["data-turbo"]

    find(:xpath, xpath).click
    assert_selector "h1", text: "Url: "+url_tit
    assert_text anchor_url


    ## Destroy Anchoring
    visit path2visit
    assert_selector xpath_section  # Anchoring should exist

    xpath_destroy = XPATHS[:anchoring][:destroy_link]
    assert_selector :xpath, xpath_destroy

    last_url = Url.last
    assert_destroy_with_text(xpath_destroy, nil) # , last_url.title)  # defined in test_system_helper.rb
    # find(:xpath, xpath_destroy).click
    refute_selector :xpath, xpath_item  # 0 Anchoring after the existing one has disappeared.
    # assert_text "successfully destroyed", wait: 0
  end  # def assert_anchoring_crud_in_show()

  # performs log on and assertion
  #
  # When returned, user_succeed is still logged on (unless it is specified nil)
  #
  # @example Simplest form, asserting non-authenticated cannot access the URL
  #   assert_index_fail_succeed(edit_place_url(@place))  # defined in test_system_helper.rb
  #
  # @example Simple form
  #   assert_index_fail_succeed(Domain.new, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  #
  # @example Full form
  #   assert_index_fail_succeed(Domain.new, "Domains", user_fail: @editor_harami, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  #
  # @param index_path [String, ActiveRecord] Either the index path or a Model record
  # @param h1_title [String, NilClass] h1 title string of the page (Model-index?) after successful login. If nil and if user_succeed is non-nil, it is guessed from the model, assuming the first argument is a model (NOT the path String).
  # @param user_fail: [User, NilClass] who fails to see the index page. if nil, the non-authorized user.
  # @param user_user_succeed: [User, NilClass] who succcessfully sees the index page
  def assert_index_fail_succeed(model, h1_title=nil, user_fail: nil, user_succeed: nil)
    index_path = model
    index_path = Rails.application.routes.url_helpers.polymorphic_path(model.class) if model.respond_to?(:destroy!) 
    h1_title ||= model.class.name.underscore.pluralize.split("_").map(&:capitalize).join(" ") if user_succeed.present?  # e.g., "Event Items"

    ## Failing in displaying index (although Login itself should succeed)
    if user_fail
      visit new_user_session_path
      assert_selector "h2", text: "Log in"
      assert_current_path new_user_session_path

      login_or_fail_index(user_fail, succeed: true)

      visit index_path
      assert_selector "h1"  # Root
      assert_current_path root_path  # should be redirected (from Index) to Root path
      logout_from_menu
    end

    return if !user_succeed

    ## Succeeding
    visit index_path  # should be redirected to new_user_session_path
    assert_current_path new_user_session_path
    assert_text TEXT_ASSERTED[:login][:need]
    assert_selector :xpath, xpath_for_flash(:alert, category: :div), text: TEXT_ASSERTED[:login][:need]
                # "//div[@id='body_main']/p[contains(@class, 'alert-danger')][1]" (and more)
    # assert page.find(:xpath, xpath_for_flash(:alert, category: :div)).text.strip.include?("need to sign in")  # redundant

    login_or_fail_index(user_succeed, succeed: true)

    assert_selector "h1", text: h1_title
  end

  # In Grid-index, this clicks "Apply" and waits for the page to be loaded, checking the change in +n_filtered_entries+
  #
  # @example
  #   user_assert_grid_index_apply_to(n_filtered_entries: 2)  # click_on "Apply" and wait for loading; defined in test_system_helper.rb
  #
  # @param #see xpath_grid_pagenation_stats_with
  # @yield [] optional Block of assertion after clicking "Apply" before this assertion to make sure this assertion waits long enough.
  #    This is recommended only when +n_filtered_entries == n_all_entries+ (either explicitly or implicitly,
  #    i.e., when +n_all_entries+ is nil but is gussed from the currently loaded HTML.
  def user_assert_grid_index_apply_to(n_filtered_entries: , n_all_entries: nil, langcode: :en, **opts)
    n_all_entries_given = n_all_entries 
    n_all_entries ||= get_grid_pagenation_n_total(langcode: langcode, for_system_test: true) # defined in test_helper.rb
    button_name = I18n.t("datagrid.form.search", locale: langcode)

    click_on button_name
    assert_selector(sprintf('input[type="submit"][value="%s"]:not([disabled])', button_name))  # Necessary
    if block_given?
      yield
    elsif n_all_entries_given.blank? && n_filtered_entries == n_all_entries
      warn "WARNING: No change in Statistics (n_filtered_entries) is expected, so this assertion may not have waited for long enough!"
    end

    puts sprintf("(#{__method__}) [Caller-Info] (%s): inner_html=%s", _get_caller_info_message, Nokogiri::HTML(page.html).xpath("/"+XPATHGRIDS[:pagenation_stats])&.inner_html&.strip.inspect) if is_env_set_positive?("PRINT_DEBUG_INFO") # defined in test_helper.rb   # If the line below fails, comment out this line and rerun the test to show the caller.
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: n_filtered_entries, n_all_entries: n_all_entries, langcode: langcode, **opts)
  end

  # Tests if a Destroy button exists
  #
  # @param should_succeed: [Boolean] false if you expect the button not to be found, making sure the page has been loaded.
  # @return [String] Xpath
  def assert_find_destroy_button(should_succeed: true)
    xpath = sprintf(XPATHS[:form][:fmt_button_submit], 'Destroy')  # defined in test_helper.rb
      # "//form[contains(@class, 'button_to')]//button[@type='submit'][contains(text(), 'Destroy')]"
    if should_succeed
      assert_selector :xpath, xpath  # Rails-7.2
      # assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']" # Rails-7.1 or earlier (or maybe config.load_defaults 6.1)
    else
      assert_no_xpath(xpath)
    end
    xpath
  end

  # Tests if Destroy succeeds
  #
  # @example
  #    assert_destroy_with_text(:first, "My dear object")  # defined in test_system_helper.rb
  #    assert_destroy_with_text("//button_to[text()='Destroy]", "My dear object")  # defined in test_system_helper.rb
  #
  # @param xpath [String, Symbol] XPath or :first. If :first, a simple algorithm is used.
  # @param obj_title [String, NilClass] "ChannelOwner" etc, which appears as H1. I nil, the message is not tested
  # @return [void]
  def assert_destroy_with_text(xpath, obj_title)
    accept_alert do
      if :first == xpath
        click_on "Destroy", match: :first
      else
        find(:xpath, xpath).click
      end
    end
    
    assert_text obj_title+" was successfully destroyed" if obj_title.present?
  end
end
