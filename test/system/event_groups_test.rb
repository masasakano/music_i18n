# coding: utf-8
require "application_system_test_case"
require "helpers/test_system_helper"

class EventGroupsTest < ApplicationSystemTestCase
  setup do
    @moderator = users(:user_moderator_general_ja)
    @event_group = event_groups(:evgr_lucky2023)
    @button_text = {
      create: "Create Event group",
      update: "Update Event group",
    }
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

    page_find_sys(:trans_new, :langcode_radio, model: EventGroup).choose('English')  # defined in helpers/test_system_helper

    # label_str = I18n.t('layouts.new_translations.title', model: 'EventGroup')
    page.find('input#event_group_title').fill_in with: 'Tekitoh'  # This is unique!

    # Test of dropdown-menu
    assert_selector 'div#div_select_country', text: "Country"
    
    assert_selector ActiveSupport::TestCase::CSSQUERIES[:hidden][:place], visible: :hidden
    assert_selector :xpath, "//form//div[@id='#{ApplicationController::HTML_KEYS[:ids][:div_sel_place]}']//div[contains(@class, 'form-group')]", visible: :hidden
    assert_equal 0, page.find_all(:xpath, "//form//div[@id='#{ApplicationController::HTML_KEYS[:ids][:div_sel_place]}']//div[contains(@class, 'form-group')][contains(@style,'display: none;')]").size

    assert     find_field('Country')
    assert_selector    'form div#div_select_country'
    #assert_selector    'form div#div_select_prefecture', visible: :hidden
    #assert_no_selector 'form div#div_select_prefecture'  # display: none
    assert_no_selector ActiveSupport::TestCase::CSSQUERIES[:hidden][:place] # display: none

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    assert_selector    'form div#div_select_prefecture'  # Now JS made it appear
    assert     find_field('Prefecture')                  # Now JS made it appear

    select @event_group.start_date.year,  from: "event_group_start_date_1i"
    select @event_group.start_date.strftime('%B'), from: "event_group_start_date_2i"
    select @event_group.start_date.strftime('%-d'), from: "event_group_start_date_3i"
    fill_in "± days (Start)", with: ""
    select @event_group.end_date.year,  from: "event_group_end_date_1i"
    select @event_group.end_date.strftime('%B'), from: "event_group_end_date_2i"
    select @event_group.end_date.strftime('%-d'), from: "event_group_end_date_3i"
    fill_in "± days (End)", with: ""
    fill_in "Note", with: @event_group.note
    #fill_in "Order no", with: @event_group.order_no  # the label may change
    #fill_in "Place", with: @event_group.place_id  # Dropdown described above
    click_on  @button_text[:create]

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

    select @event_group.start_date.year,  from: "event_group_start_date_1i"
    select @event_group.start_date.strftime('%B'), from: "event_group_start_date_2i"
    select @event_group.start_date.strftime('%-d'), from: "event_group_start_date_3i"
    fill_in "Note", with: @event_group.note
    #fill_in "Order no", with: @event_group.order_no  # the label may change
    #fill_in "Place", with: @event_group.place_id  # Dropdown described above
    endyear = Date.current.year + 5
    select endyear, from: "event_group_end_date_1i"  # This is updated!
    select @event_group.end_date.strftime('%B'), from: "event_group_end_date_2i"
    select @event_group.end_date.strftime('%-d'), from: "event_group_end_date_3i"
    fill_in "± days (End)", with: @event_group.start_date_err - 1  # This is updated!
    click_on @button_text[:update]

    assert_text "EventGroup was successfully updated"
    assert_includes find('section#primary_contents dd.item_end_date').text, endyear.to_s
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
