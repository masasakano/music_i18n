# coding: utf-8
require "test_helper"

# @example Already required in test_helper
#    require "helpers/test_system_helper"
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
  # To activate it, +ENV["CAPYBARA_LONGER_TIMEOUT"]+ must be set with an Integer in second.
  # Then, when the environmental variable is not set (the machine is not slow), 
  # none of these blocks would wait too long.
  #
  # @example
  #   with_longer_wait{ assert_selector 'section#mypart div.error_explanation'}
  #   # defined in test_system_helper.rb ; use with CAPYBARA_LONGER_TIMEOUT=3
  #
  def with_longer_wait
    if (ti=ENV["CAPYBARA_LONGER_TIMEOUT"]).present?
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
  #   assert_empty css_select(css_query(:trans_new, :is_orig_radio, model: Model))  # defined in helpers/test_system_helper
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
  #   assert_match(/ prohibited /, page_find_sys(:error_div, :title).text)  # defined in helpers/test_system_helper
  #   page_find_sys(:trans_new, :langcode_radio, model: MyModel).choose('English')  # defined in helpers/test_system_helper
  #    Old forms: page.find('form div.field.radio_langcode').choose('English')
  #   page_find_sys(:trans_new, :is_orig_radio, model: @channel_type).choose('No')  # defined in helpers/test_system_helper
  # 
  def page_find_sys(*args, **kwds)
    page.find(css_query(*args, **kwds))
  end 

  # Gets a field value, like a radio-button etc.
  #
  # @example Get a value for radio-buttons for "is_orig" in Page "new" for MyModel (e.g., ChannelType)
  #   assert_equal "on",   page_get_val(:trans_new, :is_orig, model: "my_model"), "is_orig should be Undefined, but..."  # defined in helpers/test_system_helper
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

  # performs log on and assertion
  #
  # When returned, user_succeed is still logged on (unless it is specified nil)
  #
  # @example Simplest form
  #   assert_index_fail_succeed(Domain.new, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  #
  # @example Full form
  #   assert_index_fail_succeed(Domain.new, "Domains", user_fail: @editor_harami, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  #
  # @param index_path [String, ActiveRecord] Either the index path or a Model record
  # @param h1_title [String, NilClass] h1 title string for index page. If nil, it is guessed from the model, assuming the first argument is a model (NOT the path String)
  # @param user_fail: [User, NilClass] who fails to see the index page. if nil, the non-authorized user.
  # @param user_user_succeed: [User, NilClass] who succcessfully sees the index page
  def assert_index_fail_succeed(model, h1_title=nil, user_fail: nil, user_succeed: nil)
    index_path = model
    index_path = Rails.application.routes.url_helpers.polymorphic_path(model.class) if model.respond_to?(:destroy!) 
    h1_title ||= model.class.name.underscore.pluralize.split("_").map(&:capitalize).join(" ")  # e.g., "Event Items"

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

  # Tests if a Destroy button exists
  #
  # @return [String] Xpath
  def assert_find_destroy_button
    xpath = sprintf(XPATHS[:form][:fmt_button_submit], 'Destroy')  # defined in test_helper.rb
      # "//form[contains(@class, 'button_to')]//button[@type='submit'][contains(text(), 'Destroy')]"
    assert_selector :xpath, xpath  # Rails-7.2
    # assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']" # Rails-7.1 or earlier (or maybe config.load_defaults 6.1)
    xpath
  end

  # Tests if Destroy succeeds
  #
  # @example
  #
  # @param xpath [String, Symbol] XPath or :first. If :first, a simple algorithm is used.
  # @param obj_title [String] "ChannelOwner" etc, which appears as H1
  # @return [void]
  def assert_destroy_with_text(xpath, obj_title)
    accept_alert do
      if :first == xpath
        click_on "Destroy", match: :first
      else
        find(:xpath, xpath).click
      end
    end
    
    assert_text obj_title+" was successfully destroyed"
  end
end
