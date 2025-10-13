# coding: utf-8
require "application_system_test_case"

class SiteCategoriesTest < ApplicationSystemTestCase
  setup do
    @site_category = site_categories(:one)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Site categories"
    @button_text = {
      create: "Create Site category",
      update: "Update Site category",
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting SiteCategory#index" do
    visit site_categories_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @trans_moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: @h1_title
    #assert_selector "h1", text: "Music-i18n.org for HARAMIchan (ハラミちゃん)"  # Home
    assert_text "Signed in successfully"
  end

  test "should create site category" do
    newchan = "New SiteCategory"
    visit new_site_category_url  # direct jump -> fail
    refute_text newchan
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "New SiteCategory"

    visit site_categories_url
    assert_selector "h1", text: "Site categories"
    n_records_be4 = page.all("div#site_categories table tr").size - 1
    click_on "New SiteCategory"

    page_find_sys(:trans_new, :langcode_radio, model: SiteCategory).choose('English')  # defined in test_system_helper
    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: SiteCategory), "Selection of is_orig should be presented and is Undefined in Default, but... #{str_form_for_nil.inspect} != #{page_get_val(:trans_new, :is_orig, model: SiteCategory).inspect}}"  # NOTE: if Capybara::ElementNotFound appears, check the form for the option "disable_is_orig" passed to a layout.
    page_find_sys(:trans_new, :is_orig_radio, model: @site_category).choose('Yes')
    assert_equal ApplicationController.returned_str_from_form(true), page_get_val(:trans_new, :is_orig, model: SiteCategory), "is_orig should be true, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: @site_category).choose('Undefined')
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: SiteCategory), "is_orig should become Undefined, but..."

    page.find('input#site_category_title').fill_in with: 'Tekitoh'  # This is unique!

    assert_operator 500.5, :<, find_field('Weight').value.to_f  # the weight for the "other" is 999 (See /db/seeds/site_categories.rb and /test/fixtures/site_categories.yml).

    fill_in "Mname", with: @site_category.mname
    fill_in "Note", with: @site_category.note
    click_on @button_text[:create]

    assert_match(/ prohibited /, page_find_sys(:error_div, :title).text)
    #assert_text "prohibited"
    assert_text "Mname has already been taken"
    assert_selector "h1", text: newchan

    # Language-related values in the form are also preserved.
    # Here, page_get_val() defined in test_system_helper
    assert_equal "en",   page_get_val(:trans_new, :langcode, model: SiteCategory), "Language should have been set English in the previous attempt, but..."
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: SiteCategory), "is_orig should be Undefined, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: @site_category).choose('No')  # defined in test_system_helper
    assert_equal ApplicationController.returned_str_from_form(false), page_get_val(:trans_new, :is_orig, model: SiteCategory), "is_orig should be false, but..."
    page.find('input#site_category_title').fill_in with: 'Tekitoh'  # This is unique!
    fill_in "Mname", with: "teki_toh"
    click_on @button_text[:create]

    assert_text "SiteCategory was successfully created"
    assert_equal 'Tekitoh',  page.find('table#all_registered_translations_site_category tr.lc_en td.trans_title').text
    assert_equal "teki_toh", page.find_all(:xpath, "//dt[@title='machine name']/following-sibling::dd")[0].text
    click_on "Back"

    n_records = page.all("div#site_categories table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update SiteCategory" do
    mdl2 = SiteCategory.last
    visit site_category_url(mdl2)
    click_on "Edit this SiteCategory", match: :first

    assert_selector "h1", text: "Editing SiteCategory"

    fill_in "Mname", with: "something_else"
    click_on @button_text[:update]

    assert_text "SiteCategory was successfully updated"

    # Confirming the record has been updated.
    assert_equal "something_else", page.find_all(:xpath, "//dt[@title='machine name']/following-sibling::dd")[0].text
    click_on "Back"

    ## test "should destroy SiteCategory" do
    visit site_category_url(mdl2)
    assert_selector "h1", text: "Site Category:"
    assert_match(/\ASite\s*Category:/, page.find("h1").text)

if true
    xpath = assert_find_destroy_button  # defined in test_system_helper.rb
    assert_destroy_with_text(xpath, "SiteCategory")  # defined in test_system_helper.rb
    # click_on "Destroy", match: :first  # not work as "Destroy" is now in Translation table, too.

else
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    accept_alert do
      find(:xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']").click
      # click_on "Destroy", match: :first  # not work as "Destroy" is now in Translation table, too.
    end

    #assert_text "SiteCategory was successfully destroyed"
    assert_text "was successfully destroyed"
end
    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#site_categories table tr").size - 1
    assert_equal(n_records_be4, n_records)

  end

end
