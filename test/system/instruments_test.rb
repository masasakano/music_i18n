# coding: utf-8
require "application_system_test_case"

class InstrumentsTest < ApplicationSystemTestCase
  setup do
    @instrument = instruments(:instrument_piano)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_gen = users(:user_moderator_general_ja)
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @h1_title = "Instruments"
  end

  test "visiting the index" do
    visit instruments_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @translator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "Music-i18n.org for HARAMIchan (ハラミちゃん)"  # Home
    assert_text "Signed in successfully"
  end

  test "should create engage play how" do
    visit new_instrument_url  # direct jump -> fail
    refute_text "New Instrument"
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_text "New Instrument"

    visit instruments_url
    assert_selector "h1", text: "Instruments"
    n_records_be4 = page.all("div#instruments table tr").size - 1

    click_on "New Instrument"
    assert_text "New Instrument"

    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#instrument_title').fill_in with: 'Tekitoh'  # This is unique!

    fill_in "Weight", with: @instrument.weight
    fill_in "Note", with: @instrument.note
    click_on "Create Instrument"

    assert_text "prohibited"
    assert_text "Weight has already been taken"
    assert_selector "h1", text: "New Instrument"

    ############ Language-related values in the form have disappered after failed save!
    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#instrument_title').fill_in with: 'Tekitoh'  # This is unique!
    fill_in "Weight", with: 13579.2
    click_on "Create Instrument"

    assert_text "Instrument was successfully created"
    click_on "Back"

    n_records = page.all("div#instruments table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update Instrument" do
    mdl2 = Instrument.last
    visit instrument_url(mdl2)
    click_on "Edit this Instrument", match: :first

    assert_selector "h1", text: "Editing Instrument"

    fill_in "Weight", with: 123.94

    click_on "Update Instrument"

    assert_text "Instrument was successfully updated"
    click_on "Back"

    ## test "should destroy Instrument" do
    visit instrument_url(mdl2)
    assert_match(/\AInstrument:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    find(:xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']").click
    # click_on "Destroy", match: :first  # not work as "Destroy" is now in Translation table, too.

    assert_text "Instrument was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#instruments table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
