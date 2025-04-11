require "application_system_test_case"

class DomainTitlesTest < ApplicationSystemTestCase
  setup do
    model = @domain_title = domain_titles(:one)
    @artist = artists(:artist_saki_kubota)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Domain Titles"
    but_text = model.class.name.underscore.gsub(/_/, ' ').capitalize # "Domain title" (SimpleForm default)
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
    assert_index_fail_succeed(@domain_title, @h1_title, user_fail: @editor_harami, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  end

  test "should create and edit Domain Title" do
    model = @domain_title
    css_n_records = "div#"+model.class.name.underscore.pluralize+" table tr"
    newh1 = "New DomainTitle"
    visit new_domain_title_url  # direct jump -> fail
    refute_text newh1
    assert_text "You need to sign in or sign up"


    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: newh1

    visit domain_titles_url
    assert_selector "h1", text: @h1_title
    n_records_be4 = page.all(css_n_records).size - 1

    click_on newh1
    assert_selector "h1", text: newh1

    page_find_sys(:trans_new, :langcode_radio, model: model.class).choose('English')  # defined in helpers/test_system_helper
    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: model.class), "Selection of is_orig should be presented and is Undefined in Default, but... #{str_form_for_nil.inspect} != #{page_get_val(:trans_new, :is_orig, model: model.class).inspect}}"  # NOTE: if Capybara::ElementNotFound appears, check the form for the option "disable_is_orig" passed to a layout.
    page_find_sys(:trans_new, :is_orig_radio, model: model).choose('Yes')
    assert_equal ApplicationController.returned_str_from_form(true), page_get_val(:trans_new, :is_orig, model: model.class), "is_orig should be true, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: model).choose('Undefined')
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: model.class), "is_orig should become Undefined, but..."

    page.find('input#domain_title_title').fill_in with: 'Tekitoh'  # This is unique!
    select "Unknown", from: "Site category"  # Japanese is displayed even in English environment (b/c simple_form default etc)...
    fill_in "Note", with: @domain_title.note
    fill_in "Memo editor", with: @domain_title.memo_editor
    fill_in "Weight", with: @domain_title.weight

    click_on @button_text[:create]

    assert_text "DomainTitle was successfully created"
    click_on "Back"

    ## test "should edit Domain title" do

    assert_selector css_n_records
    n_records = page.all(css_n_records).size - 1
    assert_equal(n_records_be4+1, n_records)

    mdl2 = DomainTitle.last
    visit domain_title_url(mdl2)

    click_on "Edit this DomainTitle", match: :first

    assert_selector "h1", text: "Editing DomainTitle"

    fill_in "Note", with: "something_else"
    click_on @button_text[:update]

    assert_text "DomainTitle was successfully updated"

    # Confirming the record has been updated.
    ### todo...

    click_on "Back"

    ## test "should destroy Domain title" do

    visit domain_title_url(mdl2)

    assert_match(/\ADomain\s*Title:/i, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    accept_alert do
      find(:xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']").click
      # click_on "Destroy", match: :first  # not work as "Destroy" is now in Translation table, too.
    end

    #assert_text "DomainTitle was successfully destroyed"
    assert_text "was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    assert_selector css_n_records
    n_records = page.all(css_n_records).size - 1
    assert_equal(n_records_be4, n_records)

  end

end
