# coding: utf-8
require "application_system_test_case"

class EngagePlayHowsTest < ApplicationSystemTestCase
  setup do
    @engage_play_how = engage_play_hows(:engage_play_how_piano)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_gen = users(:user_moderator_general_ja)
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @h1_title = "EngagePlayHows"
  end

  test "visiting the index" do
    visit engage_play_hows_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @translator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "Music-i18n.org for HARAMIchan (ハラミちゃん)"  # Home
    assert_text "Signed in successfully"
  end

  test "should create engage play how" do
    visit new_engage_play_how_url  # direct jump -> fail
    refute_text "New EngagePlayHow"
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit engage_play_hows_url
    n_records_be4 = page.all("div#engage_play_hows table tr").size - 1
    click_on "New EngagePlayHow"

    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#engage_play_how_title').fill_in with: 'Tekitoh'  # This is unique!

    fill_in "Weight", with: @engage_play_how.weight
    fill_in "Note", with: @engage_play_how.note
    click_on "Create EngagePlayHow"

    assert_text "prohibited"
    assert_text "Weight has already been taken"
    assert_selector "h1", text: "New EngagePlayHow"

    ############ Language-related values in the form have disappered after failed save!
    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#engage_play_how_title').fill_in with: 'Tekitoh'  # This is unique!
    fill_in "Weight", with: 13579.2
    click_on "Create EngagePlayHow"

    assert_text "EngagePlayHow was successfully created"
    click_on "Back"

    n_records = page.all("div#engage_play_hows table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update EngagePlayHow" do
    mdl2 = EngagePlayHow.last
    visit engage_play_how_url(mdl2)
    click_on "Edit this EngagePlayHow", match: :first

    assert_selector "h1", text: "Editing EngagePlayHow"

    fill_in "Weight", with: 123.94

    click_on "Update EngagePlayHow"

    assert_text "EngagePlayHow was successfully updated"
    click_on "Back"

    ## test "should destroy EngagePlayHow" do
    visit engage_play_how_url(mdl2)
    assert_match(/\AEngagePlayHow:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    click_on "Destroy", match: :first

    assert_text "EngagePlayHow was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#engage_play_hows table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
