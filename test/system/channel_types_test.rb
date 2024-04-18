# coding: utf-8
require "application_system_test_case"

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

    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#channel_type_title').fill_in with: 'Tekitoh'  # This is unique!

    assert_operator 500.5, :<, find_field('Weight').value.to_f  # Default in case of no models apart from unknown is 500
    #expect(page).to have_xpath("//input[@value='John']")
    #expect(find("input#somefield", :visible => false).value).to eq 'John'
    #page.should have_field("some_field_name", placeholder: "Some Placeholder")
    #expect(page).to have_field("field_name") { |field| field.value.present?}
    #have_field("name", with: "your name")

    fill_in "mname", with: @channel_type.mname
    fill_in "Note", with: @channel_type.note
    click_on "Create ChannelType"

    assert_match(/ prohibited /, page.find('div#error_explanation h2').text)
    #assert_text "prohibited"
    assert_text "Mname has already been taken"
    assert_selector "h1", text: newchan

    ############ Language-related values in the form have disappered after failed save!
    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#channel_type_title').fill_in with: 'Tekitoh'  # This is unique!
    fill_in "mname", with: "tekitoh"
    click_on "Create ChannelType"

    assert_text "ChannelType was successfully created"
    click_on "Back"

    n_records = page.all("div#channel_types table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update ChannelType" do
    mdl2 = ChannelType.last
    visit channel_type_url(mdl2)
    click_on "Edit this Channel Type", match: :first

    assert_selector "h1", text: "Editing Channel Type"

    fill_in "mname", with: "something_else"

    click_on "Update ChannelType"

    assert_text "ChannelType was successfully updated"
    click_on "Back"

    ## test "should destroy ChannelType" do
    visit channel_type_url(mdl2)
    assert_match(/\AChannel\s*Type:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    click_on "Destroy", match: :first

    assert_text "ChannelType was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channel_types table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
