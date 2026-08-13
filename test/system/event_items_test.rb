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

    @form_html_csses = {  # see harami_vids_test.rb
      event_group: "#event_group_id",
      year_begin:  "#year_begin",
      year_end:    "#year_end",
      event:       "#event_item_event_id"
    }.with_indifferent_access
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

    login_at_root_path(@moderator_all, with_visit: false, new_h1: "New EventItem")

    ## Already on New EventItem page
    # visit event_items_url  # index page
    # click_on "New EventItem"
    assert_selector "h1", text: "New EventItem"

    ## Event selection  (see harami_vids_test.rb where a set of thorough tests for :create is done)
    ev2select = @event
    evgr = @event_group
    assert_equal evgr.id, ev2select.event_group_id
    assert   evgr.unknown_event,               "checking fixtures to make sure"
    assert_equal 1, (node=find_all(@form_html_csses[:event]+" option")).size, "node="+find_all(@form_html_csses[:event]).map{_1[:outerHTML]}.inspect

    assert_selector @form_html_csses[:event_group]+' option'
    refute_selector @form_html_csses[:event_group]+' option[selected="selected"]'
    # select evgr.title_or_alt_for_selection, from: "Event Group"  # this does not cause an Error, but selects nothing...
    find(@form_html_csses[:event_group]).select evgr.title_or_alt_for_selection
    # This should bring up choices for Event to select

    assert_selector @form_html_csses[:event]+sprintf(' option[value="%d"]', evgr.unknown_event.id)
    assert_equal 2, (node=find_all(@form_html_csses[:event]+" option")).size, "node="+find_all(@form_html_csses[:event]).map{_1[:outerHTML]}.inspect

    year_begin2select = ev2select.start_time.year
    assert_operator evgr.start_date.year, :<, Time.current.year, "checking fixtures to make sure"
    assert_operator year_begin2select,    :<, Time.current.year, "checking fixtures to make sure"
    assert_operator 2, :<=, evgr.events.count, "checking fixtures to make sure"
    find(@form_html_csses[:year_begin]).select  year_begin2select
    # This should bring up the LuckyFes Event to select, because year is adjusted to include the year of the Event

    assert_selector @form_html_csses[:event]+sprintf(' option[value="%d"]', ev2select.id)

    # select ev2select.title_or_alt_for_selection, from: "Event", match: :prefer_exact  # Does not work... (Capybara::ElementNotFound)
    # select ev2select.title_or_alt_for_selection, from: "Event", match: :smart  # Does not work... (Capybara::ElementNotFound)
    find(@form_html_csses[:event]).select ev2select.title_or_alt_for_selection
    # find(@form_html_csses[:event]+sprintf(' option[value="%d"]', ev2select.id).select_option  # This is more exact and should work.

    ## The other parameters selection
    fill_in "Machine title", with: "my_new_title"
    select('Japan',  from: 'Country')
    # fill_in "Start Year", with: 2024
    page.find('select#event_item_start_time_1i').select("2024")
    fill_in "Duration [minute]", with: 60
    fill_in "Weight", with: ""
    fill_in "Note", with: ""
    click_on "Create Event item"

    msg_flash = "EventItem was successfully created"
    assert_text msg_flash
    # close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    # refute_text msg_flash
    assert_text "Edit this EventItem"

    evit = EventItem.find retrieve_pid_in_show  # defined in test_helper.rb
    parent_event = evit.event
    css_associate_link = ".associate_to_new_event a"
    refute_selector css_associate_link

    hvid = harami_vids(:harami_vid2)  # NOTE: At the time of writing, :harami_vid1 has :musics, but no :artist_music_plays (it should have even though it is technically allowed), whereas this :harami_vid2 has both.
    # mus1 = musics(:music_story)
    # hvid.musics << mus1
    # amp1 = ArtistMusicPlay.create!(event_item: evit, artist: Artist.third, music: mus1, play_role: PlayRole.unknown, instrument: Instrument.unknown)
    assert hvid.musics.exists?, "checking fixtures"
    assert hvid.artist_music_plays.exists?, "checking fixtures"
    evit.reload

    assert_difference("HaramiVidEventItemAssoc.count"){
      evit.harami_vids << hvid }

    page.refresh
    refute_text msg_flash
    assert_selector css_associate_link

    css = "dd.item_event"
    kwd = ev2select.title_or_alt(langcode: "en")  # "UnknownEvent"
    assert_selector css, text: kwd
    assert_difference("Event.count"){
      accept_confirm do
        click_on "Associate to a new Event"
      end

      assert_text "EventItem was successfully updated"
      assert_selector css
      refute_selector css, text: kwd
    }
    evit.reload
    refute_equal parent_event, evit.event

    click_on "Back"
  end

  test "should update and destroy Event item" do
    n_events = EventItem.count

    visit new_user_session_path
    fill_in "Email", with: @editor_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_text "Signed in successfully"

    visit event_item_url(@event_item, locale: I18n.locale)
    click_on "Edit this EventItem", match: :first

    assert_selector @form_html_csses[:event]
    fmt_sprintf = ' option[selected="selected"][value="%d"]'
    css = @form_html_csses[:event_group] + sprintf(fmt_sprintf, @event_group.id)
    assert_selector css
    css = @form_html_csses[:year_begin] + sprintf(fmt_sprintf, @event.start_time.year)
    assert_selector css
    css = @form_html_csses[:event] + sprintf(fmt_sprintf, @event.id)
    assert_selector css

    fill_in "Machine title", with: "my_updated_title"
    click_on "Update Event item"

    assert_text "EventItem was successfully updated"
    click_on "Back"
    assert_equal n_events, EventItem.count

    # Destroy
    visit event_item_url(@event_item, locale: I18n.locale)
    button_text = "Destroy this EventItem"
    
    #assert page.find(:xpath, "//input[@type='submit'][@value='#{button_text}']")["outerHTML"].present?
    refute_selector(:xpath, "//input[@type='submit'][@value='#{button_text}']")

    ### At the moment, ActiveRecord::DeleteRestrictionError
    #click_on button_text, match: :first

    #assert_text "EventItem was successfully destroyed"
    #assert_selector "h1", text: @h1_title  # should be redirected back to EventItem#index.
    #assert_equal n_events-1, EventItem.count
  end
end
