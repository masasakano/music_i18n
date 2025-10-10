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

  test "visiting Instrument index" do
    visit instruments_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @translator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "Music-i18n.org for HARAMIchan (ハラミちゃん)"  # Home
    assert_text "Signed in successfully"
  end

  test "should create Instrument and destroy" do
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
    #click_on "Back"

    ## test "should destroy Instrument" ##
    visit instrument_url(mdl2)
    assert_selector "h1", text: "Instrument: "+mdl2.title
    assert_selector "th", text: "Title"

    xpath = assert_find_destroy_button  # defined in test_system_helper.rb
    with_longer_wait(1) {
      assert_destroy_with_text(xpath, "Instrument")  # defined in test_system_helper.rb
    }

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#instruments table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
