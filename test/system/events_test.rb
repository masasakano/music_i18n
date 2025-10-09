# coding: utf-8
require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup do
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator = users(:user_moderator_general_ja)
    @event_group = event_groups(:evgr_lucky2023)  # Already has one child Event.
    @event = events(:ev_harami_lucky2023)
    @h1_title = "Events"
  end

  test "visiting the Event#index, show, then HaramiVid#show" do
    ## Events#index
    visit events_url
    assert_selector "h1", text: @h1_title
    refute_text "Events [Editor-only Page]"

    select('Single-shot street playing', from: 'Event Group')
    click_on "Apply", match: :first

    assert_selector('input[type="submit"]:not([disabled])')
    assert_selector "h1", text: @h1_title  # for some reason, this line helps suppressing Selenium::WebDriver::Error::UnknownError

    css_table_tr = "table.datagrid-table tbody tr"
    assert_operator 0, :<, find_all(css_table_tr).size

    ## Events#show
    click_on "Detail", match: :first
    assert_text "Number of registered HaramiVids"
    refute_text "Number of EventItems"
    refute_text "Editor's memo"

    # Gets Title from the title-translation table
    ev_title = trans_titles_in_table(langcode: "en", fallback: true).values.flatten.first  # defined in test_system_helper.rb
    assert  ev_title.present?

    ## HaramiVid#show
    assert_includes find_all('table#harami_vids_index_table td a').map(&:text), "Detail"
    click_on "Detail", match: :first

    css_link = "section#harami_vids_show_unique_parameters dl dd.item_event a"
    assert_selector(css_link, text: ev_title)
    assert_text "featuring Artists"  # shown below Event

    click_on ev_title, match: :first
    # find_all("section#harami_vids_show_unique_parameters dd.item_event li a")[0].click  # an exact link to click with CSS

    assert_selector "h1", text: "Event: "+ev_title
    assert_text "Number of registered HaramiVids"
    assert (ev_tit2 = trans_titles_in_table(langcode: "en", fallback: true).values.flatten.first)  # defined in test_system_helper.rb
    assert_equal ev_title, ev_tit2, "Should be back to the Event#show, but..."
  end

  test "editor should create event" do
    ## Events#index by Editor
    visit root_path
    click_on "Log in", match: :first
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_text TEXT_ASSERTED[:login][:signed_in]  # defined in test_system_helper.rb

    visit events_url
    #Capybara.using_wait_time(2){
      assert_selector "h1", text: @h1_title
    #}
    assert_text "Items"
    n_events_be4 = page.all("div#events table tr").size - 1
    click_on "Create Event"

    page.find('form section#form_edit_translation fieldset.form-group.radio_buttons.event_langcode').choose('English')

    # label_str = I18n.t('layouts.new_translations.title', model: 'EventGroup')
    page.find('input#event_title').fill_in with: 'Tekitoh'  # This is unique!

    # Test of dropdown-menu
    assert_selector 'div#div_select_country', text: "Country"
    assert_selector 'div#div_select_place div.form-group', visible: :hidden

    assert     find_field('Country')
    assert_selector    'form div#div_select_country'
    #assert_selector    'form div#div_select_prefecture', visible: :hidden
    #assert_no_selector 'form div#div_select_prefecture'  # display: none
    assert_no_selector 'form div#div_select_place div.form-group'       # display: none

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    assert_selector    'form div#div_select_prefecture'  # Now JS made it appear
    assert     find_field('Prefecture')                  # Now JS made it appear

    page.find('select#event_start_time_1i').select(@event.start_app_time.year)  # defined in module_common.rb
    page.find('select#event_start_time_2i').select("June")
    fill_in "Error", with: ""  # Form Keyword: start_err
    #select "Error Unit" ...
    fill_in "Duration [hour]", with: 5 # @event.duration_hour
    # select('Single-shot street playing', from: 'Event Group')
    fill_in "Note", with: @event.note
    #fill_in "Place", with: @event.place_id
    fill_in "Weight", with: @event.weight
    click_on "Create Event"

    assert_text "Event was successfully created"
    assert_text "Number of EventItems"
    assert_text "Editor's memo"

    click_on "Back", match: :first

    n_events = page.all("div#events table tr").size - 1
    assert_equal(n_events_be4+1, n_events)

    ## "should update Event" do
    visit event_url(@event)
    click_on "Edit this Event", match: :first

    assert_selector "h1", text: "Editing Event"
    assert_selector "h2", text: "EventItems for this Event"

    assert_selector 'form div#div_select_country'
    assert_selector 'form div#div_select_prefecture'
    assert_selector 'form div#div_select_place'

    page.find('select#event_start_time_2i').select("August")

    click_on "Update Event"

    assert_text "Event was successfully updated"
    click_on "Back", match: :first

    ## test "should destroy Event" do
    visit event_url(@event)
    assert_match(/\AEvent:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy'][@disabled='disabled']"  # "Destroy" button should be disabled because it has child EventItems
    ### This case used not to display the Destroy button at all.
    # refute_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"  # No "Destroy" button because it has child EventItems

    ### At the moment, ActiveRecord::DeleteRestrictionError (anyway, "Destroy" links in the table are disabled.)
    #assert_selector(:xpath, "//table[@id='event_items_index_table']//tbody//td//span[contains(@class, 'cell_disable_link')][text()='Destroy']")
    #refute_selector(:xpath, "//table[@id='event_items_index_table']//tbody//td//a[text()='Destroy']")

    #accept_alert do
    #  page.all(:xpath, "//table[@id='event_items_index_table']//tbody//td//a[@data-method='delete']")[1].click
    #end
    #assert_text "EventItem was successfully destroyed"  # This transited to EventItems index...
    #assert_match(/\AEvent:/, page.find("h1").text)

    #visit event_url(@event)
    #accept_alert do
    #  page.all(:xpath, "//table[@id='event_items_index_table']//tbody//td//a[@data-method='delete']")[0].click
    #end
    #assert_text "EventItem was successfully destroyed"  # This transited to EventItems index...
    #assert_match(/\AEvent:/, page.find("h1").text)

    ## Now all Child EventItems have been destroyed (see the fixtures).
    #visit event_url(@event)
    #assert_equal 0, page.all(:xpath, "//table[@id='event_items_index_table']//tbody//tr").size
    #assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"
    #click_on "Destroy", match: :first

    #assert_text "Event was successfully destroyed"

    ## should be in the Index page
    #assert_selector "h1", text: @h1_title  # should be redirected back to Event#index.
    #n_events = page.all("div#events table tr").size - 1
    #assert_equal(n_events_be4, n_events)
  end

end
