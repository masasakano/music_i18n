# coding: utf-8
require "application_system_test_case"

class EngageEventItemHowsTest < ApplicationSystemTestCase
  setup do
    @engage_event_item_how = engage_event_item_hows(:engage_event_item_how_inst_player_main)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    #@validator = W3CValidators::NuValidator.new
  end

  test "visiting the index" do
    ## Gets the sign-in path.
    visit new_user_session_path
    path2signin = current_path

    ## Visits EventItem#index => redirected to Sign-in
    visit engage_event_item_hows_url
    assert_no_selector 'div#button_create_new_place'
    assert_equal path2signin, current_path, 'Should have been redirected as normal users cannot see EngageEventItemHow#index.'
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "EngageEventItemHow index"  # should be redirected back to EngageEventItemHow#index.
    assert_text "メインゲスト"
    assert_operator page.find_all(:xpath, "//table//tbody//tr").size, :>, 1
  end

  test "should create engage event item how" do
    n_models = EngageEventItemHow.count
    visit new_engage_event_item_how_url  # direct jump -> fail
    refute_text "New EngageEventItemHow"
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @syshelper.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit engage_event_item_hows_url  # index page
    click_on "New EngageEventItemHow"

    assert_text "conductor" # inside a table
    assert_equal "unknown", find(:xpath, "//table//tr[last()]//td[2]").text, "reference table should have been sorted by weight, but..."
    assert_equal 999,       find(:xpath, "//table//tr[last()]//td[3]").text.to_f.to_i
    fill_in "Mname", with: "naiyo12"
    fill_in "Weight", with: 41.3
    fill_in "Note", with: ""
    click_on "Create Engage event item how"

    assert_text "EngageEventItemHow was successfully created"
    click_on "Back"

    assert_equal n_models+1, EngageEventItemHow.count
  end

  test "should update Engage event item how" do
    n_models = EngageEventItemHow.count
    visit new_user_session_path
    fill_in "Email", with: @syshelper.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit engage_event_item_how_url(@engage_event_item_how)
    click_on "Edit this EngageEventItemHow", match: :first

    assert_text "conductor" # inside a table
    fill_in "Mname", with: @engage_event_item_how.mname
    fill_in "Weight", with: 123456.7
    fill_in "Note", with: @engage_event_item_how.note
    click_on "Update Engage event item how"

    assert_text "EngageEventItemHow was successfully updated"
    click_on "Back"
    assert_equal n_models, EngageEventItemHow.count
    assert_equal 123456.7, @engage_event_item_how.reload.weight
  end

  ### not testing for now.
  #test "should destroy Engage event item how" do
  #  visit engage_event_item_how_url(@engage_event_item_how)
  #  click_on "Destroy this engage event item how", match: :first

  #  assert_text "Engage event item how was successfully destroyed"
  #end
end
