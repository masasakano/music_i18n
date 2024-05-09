# coding: utf-8
require "application_system_test_case"

class HaramiVidsTest < ApplicationSystemTestCase
  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @channel1 = @channel = channels(:one)
    @channel2= channels(:channel_haramichan_youtube_main)
    #@channel_owner = channel_owners(:channel_owner_saki_kubota)
    #@channel_owner2= channel_owners(:channel_owner_haramichan)
    @artist = artists(:artist_saki_kubota)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @sysadmin = users(:user_sysadmin)
    @h1_title = "Channels"
    @button_text = {
      create: "Create Channel",
      update: "Update Channel",
    }
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
    @h1_index = "HARAMIchan's Videos"
  end

  test "visiting the index and then creating one" do
    visit new_user_session_path
    fill_in "Email", with: @editor_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    # assert_response :redirect  # NoMethodError
    assert_selector "h1", text: "HARAMIchan"

    visit harami_vids_url
    assert_selector "h1", text: @h1_index

    click_on "Create a new HaramiVid"

    vid_prms = {}
    page_find_sys(:trans_new, :langcode_radio, model: HaramiVid).choose('English')  # defined in helpers/test_system_helper
    vid_prms[:title] = 'NewEnglishHaramiVid37'
    page.find('input#harami_vid_title').fill_in with: vid_prms[:title]  # This is unique!
    vid_prms[:uri] = "youtu.be/anexample37"
    fill_in "Uri", match: :first, with: vid_prms[:uri]
    vid_prms[:date] = Date.new(2021, 2, 3)
    assert_selector "div.harami_vid_release_date select#harami_vid_release_date_1i"
    find("div.harami_vid_release_date select#harami_vid_release_date_1i").select vid_prms[:date].year
    find("div.harami_vid_release_date select#harami_vid_release_date_2i").select Date::MONTHNAMES[vid_prms[:date].month]
    find("div.harami_vid_release_date select#harami_vid_release_date_3i").select vid_prms[:date].day
    # find_field("Date").fill_in with: vid_prms[:date]  # Does not work...
    vid_prms[:duration] = 450
    fill_in "Video length", with: vid_prms[:duration]

    # print "DEBUG:html=";puts page.find('div#div_select_country')['outerHTML']
    assert_selector 'div#div_select_country', text: "Country"
    assert_selector 'div#div_select_prefecture', text: "Prefecture"
    assert_selector 'div#div_select_place div.form-group', visible: :hidden
    page.find('div#div_select_country').select 'Japan'
    page.find('div#div_select_prefecture').select 'Kagawa'
    assert_selector 'div#div_select_place div.form-group'
    page.find('div#div_select_place div.form-group').select "Takamatsu Station"

    assert_equal "HARAMIchan", find_field('Channel Owner').find('option[selected]').text
    find_field('Channel Type').select('Side channel')
    assert_match(/street playing/, find_field('Event').find('option[selected]').text)
    vid_prms[:note] = "temperary note 37"
    fill_in "Note", with: vid_prms[:note]

    fill_autocomplete('Associated Artist name', with: 'Lennon', select: "John Lennon")  # defined in test_helper.rb
    find_field("Way of engagements").select "Singer (Cover)"
    fill_in "Year of engagement", with: 2009
    fill_in "Contribution", with: 0.5

    vid_prms[:music_title] = "日本語の歌37"
    fill_in "Song/Music name", with: vid_prms[:music_title]
    vid_prms[:release_year] = 2007
    fill_in "Released year", with: vid_prms[:release_year]
    vid_prms[:genre] = "Modern instrumental"  # Jazz etc are not in the fixture...
    find_field('Genre').select vid_prms[:genre]
    vid_prms[:timing] = 370
    fill_in "Timing", with: vid_prms[:timing]

    fill_autocomplete('featuring Artist', with: 'AI', select: 'AI [')  # defined in test_helper.rb
    find_field("(Music) Instrument").select "Vocal"
    find_field("How they collaborate").select "Chorus"

    click_on "Create Harami vid", match: :first

    ### Checking flash messages
    assert_text "HaramiVid was successfully created"
    assert_match(/HaramiVid was successfully created\b/, find(css_for_flash(:success)).text)  # defined in test_helper.rb
    assert_match(/Side channel\b.+ was created\b/, find(css_for_flash(:notice)).text)
    assert_match(/\bnew channel\b/i,               find(css_for_flash(:notice)+" a").text)  # <a> link should be active.

    click_on "Back"
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
