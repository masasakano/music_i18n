require "application_system_test_case"

class UrlsTest < ApplicationSystemTestCase
  setup do
    @record = @url = urls(:one)
    @model_underscore = @record.class.name.underscore
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Urls"
    but_text = @record.class.name.underscore.gsub(/_/, ' ').capitalize # "Url" (SimpleForm default)
    @button_text = {
      create: "Create #{but_text}",
      update: "Update #{but_text}",
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting the index" do
    assert_index_fail_succeed(@url, @h1_title, user_fail: @translator, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  end

  test "should create url and destroy" do
    model = @url
    css_n_records = "div#"+model.class.name.underscore.pluralize+" table tr"
    newh1 = "New Url"

    assert_index_fail_succeed(new_url_url, newh1, user_fail: nil, user_succeed: @moderator_gen)  # defined in test_system_helper.rb

    #visit urls_url  # direct jump -> fail
    #assert_text "You need to sign in or sign up"
    #refute_text newh1

    #fill_in "Email", with: @moderator_gen.email
    #fill_in "Password", with: '123456'  # from users.yml
    #click_on "Log in"
    ## assert_selector "h1", text: newh1

    visit urls_url
    assert_selector "h1", text: @h1_title
    n_records_be4 = page.all(css_n_records).size - 1

    click_on newh1
    assert_selector "h1", text: newh1

    #page_find_sys(:trans_new, :langcode_radio, model: model.class).choose('English')  # defined in test_system_helper
    #str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    #assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: model.class), "Selection of is_orig should be presented and is Undefined in Default, but... #{str_form_for_nil.inspect} != #{page_get_val(:trans_new, :is_orig, model: model.class).inspect}}"  # NOTE: if Capybara::ElementNotFound appears, check the form for the option "disable_is_orig" passed to a layout.
    #page_find_sys(:trans_new, :is_orig_radio, model: model).choose('Yes')
    #assert_equal ApplicationController.returned_str_from_form(true), page_get_val(:trans_new, :is_orig, model: model.class), "is_orig should be true, but..."
    #page_find_sys(:trans_new, :is_orig_radio, model: model).choose('Undefined')
    #assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: model.class), "is_orig should become Undefined, but..."

    assert_selector "fieldset.form-group.#{@model_underscore}_translations_is_orig"  # is_orig selection is available on :create for Url
    translation_fieldsets = all(".translation-fields")

    fill_in_new_translations([{title: 'Tekito JA-title.....oh', langcode: "ja", is_formal: false},
                              {title: 'Tekito FR-title.....oh', langcode: "fr", is_literal: true}]) # defined in test_system_helper.rb

    page.find('input#url_url').fill_in with: 'https://Tekitoh.com/abc'  # This is unique!
    select "(Automatically assigned)", from: "Domain"  # Japanese is displayed even in English environment (b/c simple_form default etc)...
    within("div.#{@model_underscore}_note") do
      fill_in "Note", with: @record.note
    end
    fill_in "Memo editor", with: @url.memo_editor
    fill_in "Weight", with: @url.weight

    click_on @button_text[:create]

    assert_selector "h1", text: "Url: "
    assert_text "Url was "+(str="successfully created")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    flash_text_system_assert("Domain created", type: :notice, category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    url_last = Url.last_created
    assert_orig_locale(nil, record: url_last)  # defined in test_system_helper.rb

    ## checking orig_locale modifications
    css_editor_only = ApplicationController.helpers.get_only_css_class(:editor)  # defined in application_helper.rb
    css_orig_locale_span = "#sec_primary_trans h2 ." + css_editor_only 
    assert_selector css_orig_locale_span
    assert_match(/orig_locale.+\bnil/, find_all(css_orig_locale_span).first.text)

    assert_selector :xpath, xpath_all_translation_table(langcode: "ja")
    refute_selector :xpath, xpath_all_translation_table(langcode: "en")  # no English Translation
    assert_selector :xpath, xpath_all_translation_table(langcode: "fr")

    assert_selector :xpath, xpath_all_translation_table(langcode: "ja", banner: true)+"//a", text: "Add translation"
    refute_selector :xpath, xpath_all_translation_table(langcode: "en", banner: true)+"//a", text: "Add translation"  # Since the user is NOT a Translator, "Add translation" button for extra languages (except for Japanese) does not appear.
    assert_selector :xpath, xpath_all_translation_table(langcode: "fr", banner: true)+"//a", text: "Add translation"

    xpath_tail = "/th//*" + ModuleCommon.xpath_contain_css(css_editor_only, complete_for: "") +
                 "//" + ModuleCommon.xpath_contain_css(Consts::Csses::Layouts::UPDATE_LINK, complete_for: "a")
    xpath_ja = xpath_all_translation_table(langcode: "ja", banner: true) + xpath_tail  # defined in test_helper.rb
    xpath_en = xpath_all_translation_table(langcode: "en", banner: true) + xpath_tail  # defined in test_helper.rb
    xpath_fr = xpath_all_translation_table(langcode: "fr", banner: true) + xpath_tail  # defined in test_helper.rb
    assert_selector :xpath, xpath_ja, text: "locale"
    refute_selector :xpath, xpath_en, text: "locale"  # no "orig_locale" in English 
    assert_selector :xpath, xpath_fr, text: "locale"

    xpath_ja_is_orig = xpath_all_translation_table(langcode: "ja", column: "trans_is_orig")  # defined in test_helper.rb
    xpath_fr_is_orig = xpath_all_translation_table(langcode: "fr", column: "trans_is_orig")  # defined in test_helper.rb

    # orig_locale => "fr"
    find(:xpath, xpath_fr).click
    assert_text "Url was "+(str="successfully updated")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    assert_selector css_orig_locale_span
    assert_selector css_orig_locale_span, text: "fr"
    assert_match(/orig_locale.+\bfr/, find_all(css_orig_locale_span).first.text)
    assert_selector :xpath, xpath_ja, text: "locale"
    refute_selector :xpath, xpath_en, text: "locale"
    assert_selector :xpath, xpath_fr, text: "ullif"  # nullify
    assert_selector :xpath, xpath_ja_is_orig, text: "No"
    assert_selector :xpath, xpath_fr_is_orig, text: "Yes"
    assert_orig_locale(:fr, record: url_last.reload)  # defined in test_system_helper.rb

    # orig_locale => nil
    find(:xpath, xpath_fr).click
    assert_text "Url was "+(str="successfully updated")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    # close_flash_windows([:notice, :success])  # defined in test_system_helper.rb  # Sometimes raises Selenium::WebDriver::Error::StaleElementReferenceError
    assert_selector css_orig_locale_span
    assert_selector css_orig_locale_span, text: "nil"
    assert_match(/orig_locale.+\bnil/, find_all(css_orig_locale_span).first.text)
    assert_selector :xpath, xpath_ja, text: "locale"
    refute_selector :xpath, xpath_en, text: "locale"
    assert_selector :xpath, xpath_fr, text: "locale"
    refute_selector :xpath, xpath_ja_is_orig, text: "No"
    refute_selector :xpath, xpath_fr_is_orig, text: "Yes"
    assert_orig_locale(nil, record: url_last.reload)  # defined in test_system_helper.rb

    # orig_locale => "ja"
    find(:xpath, xpath_ja).click
    assert_text "Url was "+(str="successfully updated")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    # close_flash_windows([:notice, :success])  # defined in test_system_helper.rb  # Sometimes raises Selenium::WebDriver::Error::StaleElementReferenceError
    assert_selector css_orig_locale_span
    assert_selector css_orig_locale_span, text: "ja"
    assert_match(/orig_locale.+\bja/, find_all(css_orig_locale_span).first.text)
    assert_selector :xpath, xpath_ja, text: "ullif"  # nullify
    refute_selector :xpath, xpath_en, text: "locale"
    assert_selector :xpath, xpath_fr, text: "locale"
    assert_selector :xpath, xpath_ja_is_orig, text: "Yes"
    assert_selector :xpath, xpath_fr_is_orig, text: "No"

    # orig_locale => "fr" again
    close_flash_windows([:notice, :success], do_assert: false)
    assert_orig_locale(:ja, record: url_last.reload)  # defined in test_system_helper.rb
    assert_equal :ja, get_orig_locale_from_translation_table(browser_locale=:en)  # defined in test_system_helper.rb
    assert_equal :fr, (ret=switch_orig_locale(:fr, dryrun: true)), ((:with_confirm == ret) ? "Confirmation pop-up should not be present, but..." : "Translation for :fr should exist but...")
    assert_equal :fr, switch_orig_locale(:fr)  # success
    assert_equal :fr, get_orig_locale_from_translation_table(browser_locale=:en)  # success confirmed

    # orig_locale => nil again
    assert_nil (ret=switch_orig_locale(nil, dryrun: true)), ((:with_confirm == ret) ? "Confirmation pop-up should not be present, but..." : "Nullify link should exist but...")
    assert_nil switch_orig_locale(nil)  # success (nil is returned on success when nil is given) # defined in test_system_helper.rb
    assert_nil get_orig_locale_from_translation_table(browser_locale=:en)  # success confirmed
    xpath = switch_orig_locale(:ko)  # should fail b/c no Korean Translation
    refute_selector :xpath, xpath  # => so, run assert_no_selector in the caller side.

    # orig_locale => "ja" again
    assert_equal :ja, switch_orig_locale(:ja)  # success
    assert_equal :ja, get_orig_locale_from_translation_table(browser_locale=:en)  # success confirmed

    # Duplicated tests (for testing assert_switch_orig_locale())
    assert_equal :nil, assert_switch_orig_locale(url_last, browser_locale=:en, to_locale: nil)  # defined in test_system_helper.rb
    assert_equal :ja,  assert_switch_orig_locale(url_last, browser_locale=:en, to_locale: :ja)  # defined in test_system_helper.rb

    ## Destory
    xp = "div.link-edit-destroy form.button_to button.destroy_link"
    assert_selector xp, text: "Destroy"
    assert_destroy_with_text(find(xp), just_click: true, chk_flash: true)  # defined in test_system_helper.rb

    assert_selector "h1", text: "Urls"

    ## test "should edit Domain title" do
    #
    # TODO............

    #fill_in "Url", with: @url.url
    #fill_in "Url normalized", with: @url.url_normalized
    #fill_in "Published date", with: @url.published_date
    #fill_in "Last confirmed date", with: @url.last_confirmed_date
    #fill_in "Weight", with: @url.weight
    #fill_in "Note", with: @url.note
    #fill_in "Memo editor", with: @url.memo_editor
    #click_on "Create Url"

    #click_on "Edit this url", match: :first
  end

  test "should not see destroy button for Url" do
    login_from_somewhere @editor_ja.email  # defined in test_system_helper.rb

    anc = Anchoring.first
    anc.url

    visit url_path(anc.url, locale: I18n.locale)
    assert_selector "h1", text: anc.url.title_or_alt(lang_fallback_option: :either, langcode: :en)

    # Should not be destroyable due to presence of anchorings.
    assert_no_selector "div.link-edit-destroy form.button_to button.destroy_link", text: "Destroy"

    click_on "Back to Index", match: :first
    assert_selector "h1", text: "Urls"
  end

end
