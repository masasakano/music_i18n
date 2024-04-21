# coding: utf-8
require "application_system_test_case"
require "helpers/test_system_helper"

class ChannelTypesTest < ApplicationSystemTestCase
  setup do
    @channel_type = channel_types(:channel_type_dictionary)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Channel Types"
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  setup do
    @channel_type = channel_types(:one)
    @button_text = {
      create: "Create Channel type",
      update: "Update Channel type",
    }
  end

  test "visiting the index" do
    visit channel_types_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @trans_moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: @h1_title
    #assert_selector "h1", text: "Music-i18n.org for HARAMIchan (ハラミちゃん)"  # Home
    assert_text "Signed in successfully"
  end

  test "should create channel type" do
    newchan = "New Channel Type"
    visit new_channel_type_url  # direct jump -> fail
    refute_text newchan
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit channel_types_url
    n_records_be4 = page.all("div#channel_types table tr").size - 1
    click_on "New ChannelType"

    page_find_sys(:trans_new, :langcode_radio, model: ChannelType).choose('English')  # defined in helpers/test_system_helper
    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: ChannelType), "is_orig should be Undefined in Default, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: @channel_type).choose('Yes')
    assert_equal ApplicationController.returned_str_from_form(true), page_get_val(:trans_new, :is_orig, model: ChannelType), "is_orig should be true, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: @channel_type).choose('Undefined')
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: ChannelType), "is_orig should become Undefined, but..."

    page.find('input#channel_type_title').fill_in with: 'Tekitoh'  # This is unique!

    assert_operator 500.5, :<, find_field('Weight').value.to_f  # Default in case of no models apart from unknown is 500

    fill_in "Mname", with: @channel_type.mname
    fill_in "Note", with: @channel_type.note
    click_on @button_text[:create]

    assert_match(/ prohibited /, page_find_sys(:error_div, :title).text)
    #assert_text "prohibited"
    assert_text "Mname has already been taken"
    assert_selector "h1", text: newchan

    # Language-related values in the form are also preserved.
    # Here, page_get_val() defined in helpers/test_system_helper
    assert_equal "en",   page_get_val(:trans_new, :langcode, model: ChannelType), "Language should have been set English in the previous attempt, but..."
    assert_equal str_form_for_nil, page_get_val(:trans_new, :is_orig, model: ChannelType), "is_orig should be Undefined, but..."
    page_find_sys(:trans_new, :is_orig_radio, model: @channel_type).choose('No')  # defined in helpers/test_system_helper
    assert_equal ApplicationController.returned_str_from_form(false), page_get_val(:trans_new, :is_orig, model: ChannelType), "is_orig should be false, but..."
    page.find('input#channel_type_title').fill_in with: 'Tekitoh'  # This is unique!
    fill_in "Mname", with: "teki_toh"
    click_on @button_text[:create]

    assert_text "ChannelType was successfully created"
    assert_equal 'Tekitoh',  page.find('table#all_registered_translations_channel_type tr.lc_en td.trans_title').text
    assert_equal "teki_toh", page.find_all(:xpath, "//dt[@title='machine name']/following-sibling::dd")[0].text
    click_on "Back"

    n_records = page.all("div#channel_types table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update ChannelType" do
    mdl2 = ChannelType.last
    visit channel_type_url(mdl2)
    click_on "Edit this Channel Type", match: :first

    assert_selector "h1", text: "Editing Channel Type"

    fill_in "Mname", with: "something_else"
    click_on @button_text[:update]

    assert_text "ChannelType was successfully updated"

    # Confirming the record has been updated.
    assert_equal "something_else", page.find_all(:xpath, "//dt[@title='machine name']/following-sibling::dd")[0].text
    click_on "Back"

    ## test "should destroy ChannelType" do
    visit channel_type_url(mdl2)
    assert_match(/\AChannel\s*Type:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    accept_alert do
      click_on "Destroy", match: :first
    end

    assert_text "ChannelType was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channel_types table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
