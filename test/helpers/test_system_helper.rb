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
  #    assert_includes trans_titles_in_table.values.flatten.map(&:downcase), "My own title".downcase  # defined in test_system_helper.rb
  #
  # @return [Hash<String => Array>] String of either title or alt_title (with_indifferent_access)
  def trans_titles_in_table
    hscss = {title: [], alt_title: []}
    hscss[:title] = find_all('section#sec_primary_trans table#all_registered_translations_harami_vid tbody tr.trans_row td.trans_title').to_a
    hscss[:alt_title] = find_all('section#sec_primary_trans table#all_registered_translations_harami_vid tbody tr.trans_row td.trans_title').to_a
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

  # performs log on
  def login_or_fail_index(user)
    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: user.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
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

    ## Failing
    if user_fail
      visit new_user_session_path
      assert_current_path new_user_session_path

      login_or_fail_index(user_fail)

      visit index_path
      assert_current_path root_path
      click_on "Log out", match: :first
      assert_text "Signed out successfully"
    end

    return if !user_succeed

    ## Succeeding
    visit index_path
    assert_current_path new_user_session_path
    assert_text "You need to sign in or sign up"

    login_or_fail_index(user_succeed)

    assert_selector "h1", text: h1_title
    assert_text "Signed in successfully"
  end
end
