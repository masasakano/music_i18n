# coding: utf-8
require "application_system_test_case"

class EventItemsTest < ApplicationSystemTestCase
  setup do
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event       = events(:ev_harami_lucky2023)
    @event_item  = event_items(:evit_1_harami_lucky2023)
    @h1_title = "Event Items"
  end

  test "visiting the index" do
    ## Gets the sign-in path.
    visit new_user_session_path
    path2signin = current_path

    ## Visits EventItem#index => redirected to Sign-in
    visit event_items_url
    assert_no_selector 'div#button_create_new_place'
    assert_equal path2signin, current_path, 'Should have been redirected as normal users cannot see EventItem#index.'
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @editor_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: @h1_title  # should be redirected back to EventItem#index.
    assert_text "Duration"
    assert_operator page.find_all(:xpath, "//table//tbody//tr").size, :>, 1
  end

  test "should create event item" do
    visit new_event_item_url  # direct jump -> fail
    refute_text "New EventItem"
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_all.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit event_items_url  # index page
    click_on "Create EventItem"

    fill_in "Machine title", with: "my_new_title"
    select('Japan',  from: 'Country')
    fill_in "Start Year", with: 2024
    fill_in "Duration [minute]", with: 60
    fill_in "Weight", with: ""
    fill_in "Note", with: ""
    click_on "Create EventItem"

    assert_text "EventItem was successfully created"
    click_on "Back"
  end

  test "should update and destroy Event item" do
    n_events = EventItem.count

    visit new_user_session_path
    fill_in "Email", with: @editor_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit event_item_url(@event_item)
    click_on "Edit this EventItem", match: :first

    fill_in "Machine title", with: "my_updated_title"
    click_on "Update EventItem"

    assert_text "EventItem was successfully updated"
    click_on "Back"
    assert_equal n_events, EventItem.count

    # Destroy
    visit event_item_url(@event_item)
    click_on "Destroy this EventItem", match: :first

    assert_text "EventItem was successfully destroyed"
    assert_selector "h1", text: @h1_title  # should be redirected back to EventItem#index.
    assert_equal n_events-1, EventItem.count
  end
end
