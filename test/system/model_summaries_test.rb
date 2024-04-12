# coding: utf-8
require "application_system_test_case"

class ModelSummariesTest < ApplicationSystemTestCase
  setup do
    #@artist = artists(:one)
    @syshelper = users(:user_syshelper)
    @moderator = users(:user_moderator)
    #@moderator = users(:user_moderator_general_ja)
    @model_summary = model_summaries(:model_summary_Artist)
    @css_swithcer_ja = 'div#language_switcher_top span.lang_switcher_ja'
    @css_swithcer_en = 'div#language_switcher_top span.lang_switcher_en'
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index" do
    # sign_in
    visit new_user_session_path
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "HARAMIchan"

    visit model_summaries_url
    assert_selector "h1", text: "Model Summary"
    assert_text "EngageHow"
    assert_text "Harami1129"
    assert_text "Engagement between Artist"
    assert_no_text "StaticPage"
  end

  test "should create/update model summary" do
    # sign_in
    visit new_user_session_path
    fill_in "Email", with: @syshelper.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "HARAMIchan"

    ## create
    visit model_summaries_url
    click_on "New ModelSummary"

    fill_in "model_summary_title", with: "新しい解説"
    fill_in "Modelname", with: "wrong_model"
    fill_in "Note", with: "tekito"
    click_on "Create Model summary"

    # should fail.
    assert_text "error prohibited"
    assert_text "capital letter"

    fill_in "model_summary_title", with: "新しい解説"
    #fill_in "ModelSummary Full Title", with: "新しい解説"
    fill_in "Modelname", with: "RightModel"
    click_on "Create Model summary"
    assert_text "ModelSummary was successfully created"
    assert_text "新しい解説"
    click_on "Back"

    ## update 
    visit model_summary_url(@model_summary)
    click_on "Edit this ModelSummary", match: :first

    fill_in "Note", with: "filled-in-note"
    click_on "Update Model summary"

    assert_text "ModelSummary was successfully updated"
    click_on "Back"

    ## destroy
    visit model_summary_url(@model_summary)
    click_on "Destroy this ModelSummary", match: :first

    assert_text "ModelSummary was successfully destroyed"
  end
end
