# coding: utf-8
require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup do
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator = users(:user_moderator_general_ja)
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event = events(:ev_harami_lucky2023)
  end

  test "visiting the index" do
    visit events_url
    assert_selector "h1", text: "Events"
    refute_text "Items"
  end

  test "should create event" do
    visit new_user_session_path
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit events_url
    assert_selector "h1", text: "Events"
    assert_text "Items"
    n_events_be4 = page.all("div#events table tr").size - 1
    click_on "Create Event"

    page.find('form div.field.radio_langcode').choose('English')

    # label_str = I18n.t('layouts.new_translations.title', model: 'EventGroup')
    page.find('input#event_title').fill_in with: 'Tekitoh'  # This is unique!

    # Test of dropdown-menu
    assert_selector 'div#div_select_country', text: "Country"
    assert_selector 'div#div_select_place', visible: :hidden

    assert     find_field('Country')
    assert_selector    'form div#div_select_country'
    #assert_selector    'form div#div_select_prefecture', visible: :hidden
    #assert_no_selector 'form div#div_select_prefecture'  # display: none
    assert_no_selector 'form div#div_select_place'       # display: none

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    assert_selector    'form div#div_select_prefecture'  # Now JS made it appear
    assert     find_field('Prefecture')                  # Now JS made it appear

    fill_in "Start Year",   with: @event.start_app_time.year
    fill_in "Start Month",  with: ""
    #fill_in "Start Day",    with: @event.start_app.day
    #fill_in "Start Hour",   with: @event.start_app.hour
    #fill_in "Start Minute", with: @event.start_app.min
    fill_in "Error", with: ""  # Form Keyword: start_err
    #select "Error Unit" ...
    fill_in "Duration [hour]", with: 5 # @event.duration_hour
    #choose "EventGroup" ...
    fill_in "Note", with: @event.note
    #fill_in "Place", with: @event.place_id
    fill_in "Weight", with: @event.weight
    click_on "Create Event"

    assert_text "Event was successfully created"
    click_on "Back"

    n_events = page.all("div#events table tr").size - 1
    assert_equal(n_events_be4+1, n_events)

    ## "should update Event group" do
    visit event_url(@event)
    click_on "Edit this Event", match: :first

    assert_selector "h1", text: "Editing Event"
    assert_selector "h2", text: "EventItems for this Event"

    assert_selector 'form div#div_select_country'
    assert_selector 'form div#div_select_prefecture'
    assert_selector 'form div#div_select_place'

    fill_in "Start Month",  with: 8  # This is updated!
    fill_in "Start Day",    with: ""  # This is updated!

    click_on "Update Event"

    assert_text "Event was successfully updated"
    click_on "Back"

    ## test "should destroy Event" do
    visit event_url(@event)
    refute_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"  # No "Destroy" button because it has child EventItems

    accept_alert do
      page.all(:xpath, "//table[@id='event_items_index_table']//tbody//td//a[@data-method='delete']")[1].click
    end
    assert_text "EventItem was successfully destroyed"  # This transited to EventItems index...

    visit event_url(@event)
    accept_alert do
      page.all(:xpath, "//table[@id='event_items_index_table']//tbody//td//a[@data-method='delete']")[0].click
    end
    assert_text "EventItem was successfully destroyed"  # This transited to EventItems index...

    # Now all Child EventItems have been destroyed (see the fixtures).
    visit event_url(@event)
    assert_equal 0, page.all(:xpath, "//table[@id='event_items_index_table']//tbody//tr").size
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"
    click_on "Destroy", match: :first

    assert_text "Event was successfully destroyed"

    # should be in the Index page
    n_events = page.all("div#events table tr").size - 1
    assert_equal(n_events_be4, n_events)
  end

end
