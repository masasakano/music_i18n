require "application_system_test_case"

class UrlsTest < ApplicationSystemTestCase
  setup do
    model = @url = urls(:one)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Urls"
    but_text = model.class.name.underscore.gsub(/_/, ' ').capitalize # "Url" (SimpleForm default)
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

  test "should create url" do
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

    page_find_sys(:trans_new, :langcode_radio, model: model.class).choose('English')  # defined in helpers/test_system_helper
    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: model.class), "Selection of is_orig should be presented and is Undefined in Default, but... #{str_form_for_nil.inspect} != #{page_get_val(:trans_new, :is_orig, model: model.class).inspect}}"  # NOTE: if Capybara::ElementNotFound appears, check the form for the option "disable_is_orig" passed to a layout.
    page_find_sys(:trans_new, :is_orig_radio, model: model).choose('Yes')
    assert_equal ApplicationController.returned_str_from_form(true), page_get_val(:trans_new, :is_orig, model: model.class), "is_orig should be true, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: model).choose('Undefined')
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: model.class), "is_orig should become Undefined, but..."

    page.find('input#url_title').fill_in with: 'Tekito title.....oh'  # This is unique!

    page.find('input#url_url').fill_in with: 'https://Tekitoh.com/abc'  # This is unique!
    select "(Automatically assigned)", from: "Domain"  # Japanese is displayed even in English environment (b/c simple_form default etc)...
    fill_in "Note", with: @url.note
    fill_in "Memo editor", with: @url.memo_editor
    fill_in "Weight", with: @url.weight

    click_on @button_text[:create]

    assert_text "Url was successfully created"
    click_on "Back"

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

 
# test "should destroy Url" do
#    visit url_url(@url)
#    click_on "Destroy this url", match: :first
#
#    assert_text "Url was successfully destroyed"
#  end
end
