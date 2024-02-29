# coding: utf-8
require "application_system_test_case"

class EventGroupsTest < ApplicationSystemTestCase
  setup do
    @moderator = users(:user_moderator_general_ja)
    @event_group = event_groups(:evgr_lucky2023)
  end

  test "visiting the index" do
    visit event_groups_url
    assert_selector "h1", text: "Event Group"
  end

  test "should create event group" do
    visit new_user_session_path
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit event_groups_url
    n_event_groups_be4 = page.all("div#event_groups table tr").size - 1
    click_on "Create EventGroup"

    page.find('form div.field.radio_langcode').choose('English')

    # label_str = I18n.t('layouts.new_translations.title', model: 'EventGroup')
    page.find('input#event_group_title').fill_in with: 'Tekitoh'  # This is unique!

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

    fill_in "Start Day",   with: @event_group.start_date.day
    fill_in "Start Month", with: @event_group.start_date.month
    fill_in "Start Year",   with: @event_group.start_date.year
    fill_in "± days (Start)", with: ""
    fill_in "Note", with: @event_group.note
    #fill_in "Order no", with: @event_group.order_no  # the label may change
    #fill_in "Place", with: @event_group.place_id  # Dropdown described above
    fill_in "End Day",   with: @event_group.end_date.day
    fill_in "End Month", with: @event_group.end_date.month
    fill_in "End Year",  with: @event_group.end_date.year
    click_on "Create EventGroup"

    assert_text "EventGroup was successfully created"
    assert_selector "section#section_event_group_show_footer a", text: "Back"
    page.find("section#section_event_group_show_footer a").click  # "Back to Index"
    #click_on "Back"

    n_event_groups = page.all("div#event_groups table tr").size - 1
    assert_equal(n_event_groups_be4+1, n_event_groups)

    ## "should update Event group" do
    visit event_group_url(@event_group)
    click_on "Edit this EventGroup", match: :first

    assert_selector 'form div#div_select_country'
    assert_selector 'form div#div_select_prefecture'
    assert_selector 'form div#div_select_place'

    fill_in "Start Day",   with: @event_group.start_date.day
    fill_in "Start Month", with: @event_group.start_date.month
    fill_in "Start Year",  with: @event_group.start_date.year
    fill_in "Note", with: @event_group.note
    #fill_in "Order no", with: @event_group.order_no  # the label may change
    #fill_in "Place", with: @event_group.place_id  # Dropdown described above
    fill_in "End Day",   with: @event_group.end_date.day
    fill_in "End Month", with: @event_group.end_date.month
    fill_in "End Year",  with: 2025  # This is updated!
    fill_in "± days (End)", with: @event_group.start_date_err - 1  # This is updated!
    click_on "Update EventGroup"

    assert_text "EventGroup was successfully updated"
    page.find("section#section_event_group_show_footer a").click  # "Back to Index"

    ## test "should destroy Event group" do
    visit event_group_url(@event_group)

    #### This EventGroup has a child and so it is not destroyable!!!!
    #click_on "Destroy this EventGroup", match: :first

    #assert_text "EventGroup was successfully destroyed"

    ## should be in the Index page
    #n_event_groups = page.all("div#event_groups table tr").size - 1
    #assert_equal(n_event_groups_be4, n_event_groups)
  end
end
