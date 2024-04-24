require "application_system_test_case"

class HaramiVidsTest < ApplicationSystemTestCase
  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @sysadmin = users(:user_sysadmin)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
    @h1_index = "HARAMIchan's Videos"
  end

  test "visiting the index and then creating one" do
    visit new_user_session_path
    fill_in "Email", with: @sysadmin.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    # assert_response :redirect  # NoMethodError
    assert_selector "h1", text: "HARAMIchan"

    visit harami_vids_url
    assert_selector "h1", text: @h1_index

    click_on "Create a new HaramiVid"

    # print "DEBUG:html=";puts page.find('div#div_select_country')['outerHTML']
    assert_selector 'div#div_select_country', text: "Country"
    assert_selector 'div#div_select_prefecture', visible: :hidden

    fill_in "URI", with: 'abcdef123'
    #fill_in "Duration", with: @harami_vid.duration

    today = Date.today
    page.find('form div.field select#harami_vid_release_date_1i').select text: today.year.to_s
    page.find('form div.field select#harami_vid_release_date_2i').select text: 'August'
    page.find('form div.field select#harami_vid_release_date_3i').select text: 15.to_s
    # fill_in "Date", with: @harami_vid.date

    check "Uploaded by Harami"

    #### So far, this test does not work BECAUSE it is not working in the app.
    #click_on "Create Harami vid"

    #assert_text "Harami vid was successfully created"
    #click_on "Back"
  end

  test "visiting the index as a guest" do
    visit grid_index_path_helper(HaramiVid, column_names: ["events", "collabs"], max_per_page: 25)
    assert_selector "h1", text: @h1_index

    tit_lucky = events(:ev_harami_lucky2023).title(langcode: "en")  # HARAMIchan at LuckyFes 2023
    assert_text "The Proclaimers"  # NOT "Proclaimers, The"
    assert_text tit_lucky  # in "feat. Artists"
    assert_selector 'table thead th.events', text: "Events"
    assert_selector 'table thead th.collabs', text: "feat. Artists"

    htmlcapy_hed = page.all('table thead tr')[-1].all('th')[6]
    assert_equal    htmlcapy_hed.text, "Events"
    htmlcapy_evt = page.all('table tbody tr')[-1].all('td')[6]
    htmlcapy_art = page.all('table tbody tr')[-1].all('td')[7]
    assert_equal    htmlcapy_evt.text, tit_lucky 
    assert_includes htmlcapy_evt['innerHTML'], tit_lucky
    refute_includes htmlcapy_evt['innerHTML'], "<a"  # link hidden for unauthorized in Events
    assert_includes htmlcapy_art['innerHTML'], "<a"  # link visible to anyone in feat. Artists
  end

  # test "updating a Harami vid" do
  #   visit harami_vids_url
  #   click_on "Edit", match: :first

  #   fill_in "Date", with: @harami_vid.date
  #   fill_in "Duration", with: @harami_vid.duration
  #   check "Flag by harami" if @harami_vid.flag_by_harami
  #   fill_in "Note", with: @harami_vid.note
  #   fill_in "Place", with: @harami_vid.place_id
  #   fill_in "Uri", with: @harami_vid.uri
  #   fill_in "Uri playlist en", with: @harami_vid.uri_playlist_en
  #   fill_in "Uri playlist ja", with: @harami_vid.uri_playlist_ja
  #   click_on "Update Harami vid"

  #   assert_text "Harami vid was successfully updated"
  #   click_on "Back"
  # end

  # test "destroying a Harami vid" do
  #   visit harami_vids_url
  #   page.accept_confirm do
  #     click_on "Destroy", match: :first
  #   end

  #   assert_text "Harami vid was successfully destroyed"
  # end
end
