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
    @h1_index = "HARAMIchan's Videos"
    @button_text = {
      create: "Create Channel",
      update: "Update Channel",
    }
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "public visiting the index" do
    visit harami_vids_url
    assert_selector "h1", text: @h1_index
    assert_no_selector "div#new_harami_vid_link"

    css_table = "table.datagrid tbody tr"
    size_be4 = find_all(css_table).size

    fill_autocomplete('#harami_vids_grid_musics', use_find: true, with: 'Peace a', select: (tit="Give Peace"))  # defined in test_helper.rb
    # NOTE:  "Title [ja+en] (partial-match)" does not work well.  => Syntax error, unrecognized expression: #Title [ja+en] (partial-match)

    click_on "Apply"

    assert_selector "h1", text: @h1_index
    size_aft = find_all(css_table).size
    assert_operator size_be4, :>, size_aft
    assert_equal 1, size_aft

    click_on "Reset"

    assert_selector "h1", text: @h1_index
    assert_equal size_be4, find_all(css_table).size  # size should be refreshed.

    fill_autocomplete('#harami_vids_grid_artists', use_find: true, with: 'nnon', select: (tit="John Lennon"))  # defined in test_helper.rb
    click_on "Apply"

    assert_equal 1, find_all(css_table).size
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

    exp = "Create a new HaramiVid"
    assert_selector "div#new_harami_vid_link", text: exp
    click_on exp

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
    assert_match(/street playing/, find_field('Event', match: :first).find('option[selected]').text)
    vid_prms[:note] = "temperary note 37"
    fill_in "Note", with: vid_prms[:note]

    fill_autocomplete('Associated Artist name', with: 'Lennon', select: (vid_prms[:engage_artist_text]="John Lennon"))  # defined in test_helper.rb
    find_field("Way of engagement").select(vid_prms[:engage_how_text]="Singer (Cover)")
    fill_in "Year of engagement", with: (vid_prms[:engage_year]=2009)
    fill_in "Contribution",       with: (vid_prms[:engage_contribution]=0.5)

    vid_prms[:music_title] = "日本語の歌37"
    fill_in "Song/Music name", with: vid_prms[:music_title]
    vid_prms[:release_year] = 2007
    fill_in "Released year", with: vid_prms[:release_year]
    vid_prms[:genre] = "Modern instrumental"  # Jazz etc are not in the fixture...
    find_field('Genre').select vid_prms[:genre]
    vid_prms[:timing] = 370
    fill_in "Timing", with: vid_prms[:timing]

###########  This is now disabled in new...  Modify the system test!!
    fill_autocomplete('featuring Artist', with: 'AI', select: 'AI [')  # defined in test_helper.rb
    find_field("(Music) Instrument").select "Vocal"
    find_field("How they collaborate").select "Chorus"

    click_on "Create Harami vid", match: :first

    ### Checking flash messages
    assert_text "HaramiVid was successfully created"
    assert_match(/HaramiVid was successfully created\b/, find(css_for_flash(:success)).text)  # defined in test_helper.rb
    assert_match(/Side channel\b.+ was created\b/, find(css_for_flash(:notice)).text)
    assert_match(/\bnew channel\b/i,               find(css_for_flash(:notice)+" a").text)  # <a> link should be active.

    ### checking the create-result in Show
    _check_at_show(vid_prms)

    selector_tr = "table#music_table_for_hrami_vid tbody tr "
    assert_equal vid_prms[:music_title],       find(selector_tr+"td.item_title a").text  # link
    music = Music.find(find(selector_tr+"td.item_title a")["href"].to_s.split("/")[-1].to_i)
    assert_equal vid_prms[:release_year].to_s, find(selector_tr+"td.item_year").text
    assert_equal vid_prms[:release_year].to_i, music.year
    assert_equal vid_prms[:genre],             find(selector_tr+"td.item_genre").text
   #assert_equal vid_prms[:place]   # Music's Place is unknown.
    assert   music.place.unknown?   # Music's Place is unknown.

    assert_equal 1, music.engages.count
    engage = music.engages.first
    assert_equal vid_prms[:engage_artist_text], find(selector_tr+"td.item_artists a").text
    assert_equal vid_prms[:engage_artist_text],  engage.artist.title
    assert_match(/#{Regexp.quote(vid_prms[:engage_how_text])}/, find(selector_tr+"td.item_artists").text)
    assert_equal vid_prms[:engage_year],         engage.year
    assert_equal vid_prms[:engage_contribution], engage.contribution

    assert_equal "06:10",       find(selector_tr+"td.item_timing").text  #  vid_prms[:timing].to_s == "370"  => 06:10

    find("#main_edit_button").click
    #click_on "Edit"  # => Ambiguous match, found 3 elements matching visible link or button "Edit"

    ## Editing

    vid_prms[:date_edit] = vid_prms[:date] + 1
    find("div.harami_vid_release_date select#harami_vid_release_date_3i").select vid_prms[:date_edit].day
    page.has_field?('section#sec_primary_input checkboxes', checked: true)
    assert_equal "HARAMIchan",   find_field('Channel Owner').find('option[selected]').text
    assert_equal 'Side channel', find_field('Channel Type').find('option[selected]').text

    uncheck 'UnknownEventItem'  # should be invalid because it is an "unknown" EventItem and also it has an Artist
    select 'street playing', from: 'Additional Event', match: :first  # in the same way

    fill_autocomplete('Music name', with: vid_prms[:music_title][0..-2], select: vid_prms[:music_title][0..-2])  # same song; defined in test_helper.rb
    fill_autocomplete('featuring Artist', with: 'Proclai', select: 'Proclaimers')  # defined in test_helper.rb
    find_field("(Music) Instrument").select(vid_prms[:instrument_edit]="Vocal")
    find_field("How they collaborate").select(vid_prms[:collab_how_edit]= "Singer")

    click_on "Update Harami vid", match: :first

    ### Checking flash messages
    assert_match(/\bEvent.* must be checked\b/, find(css_for_flash(:alert, category: :error_explanation)).text)
    check 'UnknownEventItem'  # In fact, this should be forcibly checked again in default when an error takes you back to the screen after unchecked.
    click_on "Update Harami vid", match: :first

    assert_match(/HaramiVid was successfully updated\b/, find(css_for_flash(:success)).text)  # defined in test_helper.rb
    _check_at_show(vid_prms)

    sel = "section#harami_vids_show_unique_parameters dl "+"dd.item_event ol.list_event_items"
    assert_match(/\b#{Regexp.quote(vid_prms[:music_title])}\b/, find(sel+" li:nth-child(1)").text)
    assert_match(/\bfeat.+ Artists \(None\)/, find(sel+" li:nth-child(2)").text)  # Though a new EventItem is created, the existing EventItem is checked for the new featuring-Artist, and hence the second one has no featuring Artists. 
    assert_match(/\bfeaturing Artist.+\bThe Proclaimers\b/i,                 find(sel).text)
    assert_selector sel+" a"

    click_on "Back"
  end

  def _check_at_show(vid_prms)
    assert_equal vid_prms[:title], find("table#all_registered_translations_harami_vid tr.trans_row.lc_en td.trans_title").text.strip

    selector_dl = "section#harami_vids_show_unique_parameters dl "
    assert_equal vid_prms[:uri],  find(selector_dl+" dd.item_uri a").text
    assert_equal "https://youtu.be/",  find(selector_dl+"dd.item_uri a")["href"].to_s[0,17]
    assert_equal (vid_prms[:date_edit] || vid_prms[:date]).to_s, find(selector_dl+"dd.item_release_date").text
    assert_equal vid_prms[:duration], find(selector_dl+"dd.item_duration").text.to_f
    assert_selector selector_dl+"dd.item_channel a"
    assert_match(/Side channel\b/, find(selector_dl+"dd.item_channel").text)

    sel = selector_dl+"dd.item_event ol.list_event_items li:first-child"
    assert_match(/\b#{Regexp.quote(vid_prms[:music_title])}\b/, find(sel).text)
    assert_match(/\bfeaturing Artist.+\bAI\b/i,                 find(sel).text)
    assert_selector sel+" a"

    assert_text vid_prms[:note]
  end
  private :_check_at_show

  test "visiting the index as a guest" do
    visit grid_index_path_helper(HaramiVid, column_names: ["events", "collabs"], max_per_page: 25)
    assert_selector "h1", text: @h1_index

    tit_lucky = events(:ev_harami_lucky2023).title(langcode: "en")  # HARAMIchan at LuckyFes 2023
    assert_text "The Proclaimers"  # NOT "Proclaimers, The"
    assert_text tit_lucky  # in "feat. Artists"
    assert_selector 'table thead th.events', text: "Events"
    assert_selector 'table thead th.collabs', text: "feat. Artists"

    htmlcapy_hed = page.all('table thead tr')[-1].all('th')[5]
    assert_equal    htmlcapy_hed.text, "Events"
    htmlcapy_evt = page.all('table tbody tr')[-1].all('td')[5]
    htmlcapy_art = page.all('table tbody tr')[-1].all('td')[6]
    assert_equal    htmlcapy_evt.text, tit_lucky 
    assert_includes htmlcapy_evt['innerHTML'], tit_lucky
    refute_includes htmlcapy_evt['innerHTML'], "<a"  # link hidden for unauthorized in Events
    assert_includes htmlcapy_art['innerHTML'], "<a"  # link visible to anyone in feat. Artists
  end

  test "edit music timing at show" do
    hvid = harami_vids :harami_vid3

    # unauthenticated user
    visit harami_vid_path(hvid)
    assert_selector "h1", text: "HARAMIchan-featured Videos"  # locale: harami_vid_long: 
    assert_includes trans_titles_in_table.values.flatten, hvid.title_or_alt(langcode: "en", lang_fallback_option: :either)

    trs_css = "section#harami_vids_show_musics table tbody tr td.item_timing"
    trs = find_all(trs_css)

    assert_includes hvid.harami_vid_music_assocs, (hvma1=harami_vid_music_assocs(:harami_vid_music_assoc3))  # check fixtures
    assert hvma1.timing.blank?, 'checking fixtures'
    assert_includes hvid.harami_vid_music_assocs, (hvma2=harami_vid_music_assocs(:harami_vid_music_assoc_3_ihojin1))  # check fixtures
    assert_operator 1, :<, hvma2.timing, 'checking fixtures'

    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find('a').text
    assert_raises(Capybara::ElementNotFound){
      trs[0].find('form') }
    assert_equal "00:00", trs[1].find('a').text  # Even when timing is nil, a significant text is displayed so that <a> tag is valid.

    # HaramiEditor
    visit new_user_session_path
    fill_in "Email", with: @editor_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "HARAMIchan"

    visit harami_vid_path(hvid)
    assert_selector "h1", text: "HARAMIchan-featured Videos"  # locale: harami_vid_long: 

    trs = find_all(trs_css)
    timing_a_css = 'span.timing-hms a'
    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find(timing_a_css).text
    submit_css = "form input[value=Edit]"

    assert_selector (trs_css+" "+submit_css)
    trs[0].find(submit_css).click

    # Edit mode
    assert_selector trs_css+' input#form_timing'  # This must come BEFORE the assert_raises below because this method would wait (for up to a couple of seconds) till the condition is satisfied as a result of JavaScript's updating the page.
    trs = find_all(trs_css)
    assert_raises(Capybara::ElementNotFound){
      trs[0].find(timing_a_css) }  # In the Edit-mode row, there is no value and link displayed.
    assert trs[1].find(timing_a_css).present?  # Other rows unchanged.

    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find('input#form_timing')["value"]
    assert_equal "commit", trs[0].find('input[type=submit]')["name"]

    trs[0].find('input#form_timing').fill_in with: "-6"
    trs[0].find('input[type=submit]').click

    # After an erroneous submit
    assert_selector trs_css+' div#error_explanation'
    trs = find_all(trs_css)
    assert_match(/must be 0 or positive\b/, trs[0].find('div#error_explanation').text)  # => Timing(-6) must be 0 or positive.
    assert_equal("-6", trs[0].find('input#form_timing')["value"], "Negative value should stay in the form field, but...")  # Errror message displayed in the same cell

    assert_equal "Cancel", trs[0].find("a").text  # button-like "Cancel" link
    trs[0].find("a").click

    # Show mode again after "cancelling"
    assert_selector (trs_css+" "+submit_css)
    trs = find_all(trs_css)
    assert_selector "h1", text: "HARAMIchan-featured Videos"  # locale: harami_vid_long: 
    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find(timing_a_css).text, "value should be reverted back, but..."
    trs[0].find(submit_css).click

    # Edit mode
    assert_selector trs_css+' input#form_timing'
    trs = find_all(trs_css)
    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find('input#form_timing')["value"]
    trs[0].find('input#form_timing').fill_in with: "72"
    trs[0].find('input[type=submit]').click

    # Show mode again after successful submission
    #   At the top, "Success" message is displayed... (but nobody would notice it!)
    assert_selector (trs_css+" "+submit_css)
    trs = find_all(trs_css)
    assert_selector "h1", text: "HARAMIchan-featured Videos"  # locale: harami_vid_long: 
    assert_equal "01:12", trs[0].find(timing_a_css).text, "value should be updated, but..."
    assert_equal "Edit", trs[0].find(submit_css)["value"]
  end

  # test "destroying a Harami vid" do
  #   visit harami_vids_url
  #   page.accept_confirm do
  #     click_on "Destroy", match: :first
  #   end

  #   assert_text "Harami vid was successfully destroyed"
  # end
end
