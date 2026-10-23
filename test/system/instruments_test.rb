# coding: utf-8
require "application_system_test_case"

class InstrumentsTest < ApplicationSystemTestCase
  setup do
    @record = @instrument = instruments(:instrument_piano)
    @model_underscore = @record.class.name.underscore
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_gen = users(:user_moderator_general_ja)
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @h1_title = "Instruments"
    but_text = @record.class.name.underscore.gsub(/_/, ' ').capitalize # "Instrument" (SimpleForm default)
    @button_text = {
      create: "Create #{but_text}",
      update: "Update #{but_text}",
    }
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
    newh1 = "New Instrument"
    assert_index_fail_succeed(new_instrument_url, newh1, user_fail: nil, user_succeed: @moderator_gen)  # defined in test_system_helper.rb

    visit instruments_url
    assert_selector "h1", text: @h1_title
    n_records_be4 = page.all("div#instruments table tr").size - 1

    click_on newh1
    assert_selector "h1", text: newh1
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    refute_selector "fieldset.form-group.#{@model_underscore}_translations_is_orig"  # is_orig selection is NOT available on :create for Instrument
    translation_fieldsets = all(".translation-fields")

    # --- Translation Set 1 ---
    within(translation_fieldsets[0]) do
      fill_in "Title", with: 'Tekitoh'
      select "ja", from: "Language"
    end

    fill_in "Weight", with: @instrument.weight
    within("div.#{@model_underscore}_note") do
      fill_in "Note", with: @record.note
    end
    click_on "Create Instrument"

    assert_text "prohibited"
    assert_text (str="Weight has already been taken")
    flash_text_system_assert(str, type: [:alert], category: :div)  # defined in test_helper.rb  # This is NOT a flash message.
    assert_selector "h1", text: "New Instrument"

    ## Language-related values should be preserved in the relevant fields
    fill_in "Weight", with: 13579.2

    click_on @button_text[:create]

    assert_selector "h1", text: "Instrument: "
    assert_text "Instrument was "+(str="successfully created")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb

    click_on "Back"

    n_records = page.all("div#instruments table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update Instrument" do
    mdl2 = Instrument.last
    visit instrument_url(mdl2, locale: I18n.locale)
    click_on "Edit this Instrument", match: :first

    assert_selector "h1", text: "Editing Instrument"

    fill_in "Weight", with: 123.94

    click_on "Update Instrument"

    assert_text "Instrument was successfully updated"
    #click_on "Back"

    ## test "should destroy Instrument" ##
    visit instrument_url(mdl2, locale: I18n.locale)
    assert_selector "h1", text: "Instrument: "+mdl2.title
    assert_selector "th", text: "Title"

    xpath = assert_find_destroy_button  # defined in test_system_helper.rb
    with_longer_wait(1) {
      assert_destroy_with_text(xpath, "Instrument", chk_flash: true)  # defined in test_system_helper.rb
    }

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#instruments table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
