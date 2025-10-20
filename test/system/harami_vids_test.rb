# coding: utf-8
require "application_system_test_case"

class HaramiVidsTest < ApplicationSystemTestCase
  # XPath (Rails-7.2) for table cell in Music Table in HaramiVid#show
  XPATH_MUSIC_TD = "//table[@id='music_table_for_hrami_vid']//tbody//tr//td"

  XPATH_TD_TIMING = XPATH_MUSIC_TD + "[contains(@class, 'item_timing')]"
  XPATH_TD_NOTE   = XPATH_MUSIC_TD + "[contains(@class, 'item_note')]"

  # XPath (Rails-7.2) for Edit button in a table cell for timing
  XPATH_TD_TIMING_EDIT = XPATH_TD_TIMING + sprintf(XPATHS[:form][:fmt_any_button_submit], 'Edit') # defined in test_helper.rb # (Rails-7.2)

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
    @update_haramivid_button = "Update Harami vid"
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

  test "public visiting HaramiVid#index" do
    n_tot_entries = HaramiVid.count
    visit harami_vids_url
    assert_selector "h1", text: @h1_index
    assert_no_selector "div#new_harami_vid_link"
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: n_tot_entries) # defined in test_helper.rb

    css_table = CSSGRIDS[:tb_tr]
    size_be4 = find_all(css_table).size

    fill_autocomplete('#harami_vids_grid_musics', use_find: true, with: 'Peace a', select: (tit="Give Peace"))  # defined in test_helper.rb
    # NOTE:  "Title [ja+en] (partial-match)" does not work well.  => Syntax error, unrecognized expression: #Title [ja+en] (partial-match)

    click_on "Apply"

    assert_selector('input[type="submit"][value="Apply"]:not([disabled])')
    assert_text 'Page 1 (1—1)/1'  # Page 1 (1—1)/1 [Grand total: 12]
    assert_text             xpath_grid_pagenation_stats_with(n_filtered_entries: 1, text_only: true)
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: 1) # defined in test_helper.rb
    assert_selector "h1", text: @h1_index
    assert_selector "table", text: "Give Peace"
    assert_text tit
    size_aft = find_all(css_table).size
    assert_operator size_be4, :>, size_aft
    assert_equal 1, size_aft

    click_on "Reset"
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: n_tot_entries) # defined in test_helper.rb
    assert_equal size_be4, find_all(css_table).size  # size should be refreshed.

    fill_autocomplete('#harami_vids_grid_artists', use_find: true, with: 'nnon', select: (tit="John Lennon"))  # defined in test_helper.rb
    click_on "Apply"

    assert_selector('input[type="submit"][value="Apply"]:not([disabled])')
    assert_selector "table", text: "John Lennon"
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: 1) # defined in test_helper.rb
    assert_equal 1, find_all(css_table).size, find_all(css_table).to_a.map{|i| i['innerHTML']}.inspect

    click_on "Reset"
    assert_selector "table", text: "John Lennon"
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: n_tot_entries) # defined in test_helper.rb
    assert_equal size_be4, find_all(css_table).size  # size should be refreshed.

    ## Now displaying 3 more columns
    fill_in "(Original) Artist", with: nil
    check "Type"
    check "Owner"
    check "Platform"

    refute_includes find_all("table th").to_a.map(&:text), "Platform"
    n_ths = find_all("table th").size
    click_on "Apply"
    assert_selector "table th", text: "Platform"
    assert_selector('input[type="submit"][value="Apply"]:not([disabled])')
    assert_includes find_all("table th").to_a.map{ _1.text.sub(/\n.+/m, "") }, "Platform"  # th == "Platform\n↑ ↓"
    assert_equal n_ths+3, find_all("table th").size

    ## Now, selecting HARAMIchan Side Channel only (on Youtube).
    select_owner = page.find('#harami_vids_grid_channel_owner')
    select_type  = page.find('#harami_vids_grid_channel_type')
    assert select_owner
    n_owner_having_vids = ChannelOwner.joins(:channels).joins(channels: :harami_vids).distinct.count
    assert_operator n_owner_having_vids, :<=, ChannelOwner.count
    assert_operator n_owner_having_vids, :<, (si = select_owner.find_all('option').size), select_owner.find_all('option').to_a.map{|i| i['innerHTML']}
    assert_equal    n_owner_having_vids+1, si  # +1 for NULL option (i.e., select none)
    select_owner.select "HARAMIchan" 
    select_type.select  "Side"  # "Side channel" 
    # ch_harami_youtube_main = channels(:channel_haramichan_youtube_main)
    ch_harami_youtube_sub  = channels(:channel_haramichan_youtube_sub)
    ch_harami_instagram_main = channels(:channel_haramichan_instagram_main)

    click_on "Apply"
    # exp_n_vids = HaramiVid.joins(:channel).where("channels.id" => [ch_harami_youtube_main, ch_harami_youtube_sub].map(&:id)).distinct.count  # Both Main and Side channels of Youtube
    exp_n_vids = HaramiVid.joins(:channel).where("channels.id": ch_harami_youtube_sub.id).distinct.count
    assert_operator exp_n_vids, :>, 0, "Sanity check of fixtures: Number of HaramiVid on SideChannel should be 1 (or larger), but..."
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: exp_n_vids) # defined in test_helper.rb
    assert_selector('input[type="submit"][value="Apply"]:not([disabled])')

    all_tds = find_all("table td").to_a.map(&:text).join(" ")  # "HARAMI_PIANO 2nd [Side]"
    assert_includes all_tds, "[Side]"
    refute_includes all_tds, "Instagram"
    # assert_selector "table td", text: "[Side]"
    # refute_selector "table td", text: "Instagram"

    ## Now, selecting HARAMIchan (whatever-type) Channel on Instagram only.
    exp_n_vids = HaramiVid.joins(:channel).where("channels.id": ch_harami_instagram_main.id).distinct.count
    assert_operator exp_n_vids, :>, 0, "Sanity check of fixtures: Number of HaramiVid on Instagram should be 1 (or larger), but..."

    select_type.select  ""  # NONE
    select_platform = page.find('#harami_vids_grid_channel_platform')
    select_platform.select "Instagram"

    click_on "Apply"
    refute_selector "table td", text: "[Side]"  # Essential because the number of entries has not change in "Apply"!
    assert_selector "table td", text: "Instagram"
    assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: exp_n_vids) # defined in test_helper.rb
    assert_selector('input[type="submit"][value="Apply"]:not([disabled])')
  end

  test "visiting HaramiVid index and then creating one" do
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
    page_find_sys(:trans_new, :langcode_radio, model: HaramiVid).choose('English')  # defined in test_system_helper
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
    find_field('Channel Type').select('Other')
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

    fill_autocomplete('featuring Artist', with: 'AI', select: 'AI [')  # defined in test_helper.rb
    find_field("(Music) Instrument").select "Vocal"
    find_field("How they collaborate").select "Chorus"

    click_on "Create Harami vid", match: :first

    ### Checking flash messages
    assert_text "HaramiVid was successfully created"
    assert_match(/HaramiVid was successfully created\b/, find_all(css_for_flash(:success)).first.text)  # defined in test_helper.rb # There are multiple matches likely because of Turbo-frames
    assert_match(/Other\b.* was created\b/, find_all(css_for_flash(:notice)).first.text)
    assert_match(/\bnew channel\b/i,               find_all(css_for_flash(:notice)+" a").first.text)  # <a> link should be active.

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

    assert_equal "06:10",       find(selector_tr+"td.item_timing span.text-start").text  #  vid_prms[:timing].to_s == "370"  => 06:10

    find("#main_edit_button").click
    #click_on "Edit"  # => Ambiguous match, found 3 elements matching visible link or button "Edit"

    ## Editing

    vid_prms[:date_edit] = vid_prms[:date] + 1
    find("div.harami_vid_release_date select#harami_vid_release_date_3i").select vid_prms[:date_edit].day
    page.has_field?('section#sec_primary_input checkboxes', checked: true)
    assert_equal "HARAMIchan",   find_field('Channel Owner').find('option[selected]').text
    assert_equal 'Other types', find_field('Channel Type').find('option[selected]').text
    # assert_equal 'Side channel', find_field('Channel Type').find('option[selected]').text

    uncheck 'UnknownEventItem'  # should be invalid because it is an "unknown" EventItem and also it has an Artist
    select 'street playing', from: 'Additional Event', match: :first  # in the same way

    fill_autocomplete('Music name', with: vid_prms[:music_title][0..-2], select: vid_prms[:music_title][0..-2])  # same song; defined in test_helper.rb
    fill_autocomplete('featuring Artist', with: 'Proclai', select: 'Proclaimers')  # defined in test_helper.rb
    find_field("(Music) Instrument").select(vid_prms[:instrument_edit]="Vocal")
    find_field("How they collaborate").select(vid_prms[:collab_how_edit]= "Singer")

    click_on @update_haramivid_button, match: :first

    ### Checking flash messages (the submit must have failed.)
    assert_text 'prohibited this HaramiVid from being saved'
    assert_match(/\bprohibited this HaramiVid from being saved\b/, find_all(css_for_flash(:alert, category: :error_explanation))[0].text)
    assert_match(/\bEvent.* must be checked\b/, find_all(css_for_flash(:alert, category: :error_explanation))[0].text)  # TODO: two matches...
    check 'UnknownEventItem'  # In fact, this should be forcibly checked again in default when an error takes you back to the screen after unchecked.
    select 'street playing', from: 'Additional Event', match: :first  # in the same way; Although a new Event is specified, "New EventItem" is not chosen, so this should take no effect (after Git a2869ee).  Note a new Event is always selected as long as HaramiVid is already associated with an Event.  Before Git-commit a2869ee, whenever a new Event is selected, a new EventItem is always created, where the EventItem to which a newly specified Music would be associated was completely independently specified, and this test was written as such.

    click_on @update_haramivid_button, match: :first

    assert_text 'HaramiVid was successfully updated'
    assert_match(/HaramiVid was successfully updated\b/, find_all(css_for_flash(:success)).first.text)  # defined in test_helper.rb
    _check_at_show(vid_prms)

    sel = "section#harami_vids_show_unique_parameters dl "+"dd.item_event ol.list_event_items"
    assert_match(/\b#{Regexp.quote(vid_prms[:music_title])}\b/, find(sel+" li:nth-child(1)").text)
    assert_equal 1, find_all(sel+" li").size
    assert_match(/\bfeaturing Artist.+\bThe Proclaimers\b/i,    find(sel).text)
    assert_match(/\bfeat.+ Artists.+\bThe Proclaimers/,         find(sel+" li:nth-child(1)").text)
    assert_selector sel+" a"

    ## Now, we add a new EventItem without associated Music or featuring/collaborating Artist
    find("#main_edit_button").click

    choose 'new EventItem'   # This becomes mandatory at Git a2869ee (it used to be not).
    # find('section#form_choose_event_item_for_new_music_artist fieldset input#harami_vid_form_new_artist_collab_event_item_0').choose  # More precise way to specify Radio-button choose
    select 'street playing', from: 'Additional Event', match: :first  # in the same way

    # fill_in('featuring Artist', with: "")  # To reset the featuring Artist; should be unnecessary!
    click_on @update_haramivid_button, match: :first

    assert_text 'HaramiVid was successfully updated'
    assert_match(/HaramiVid was successfully updated\b/, find_all(css_for_flash(:success)).first.text)  # defined in test_helper.rb
    _check_at_show(vid_prms)

    sel = "section#harami_vids_show_unique_parameters dl "+"dd.item_event ol.list_event_items"
    assert_match(/\b#{Regexp.quote(vid_prms[:music_title])}\b/, find(sel+" li:nth-child(1)").text)
    assert_match(/\bfeaturing Artist.+\bThe Proclaimers\b/i,    find(sel).text)
    assert_match(/\bfeat.+ Artists.+\bThe Proclaimers/,         find(sel+" li:nth-child(1)").text)
    assert_match(/\bfeat.+ Artists \(None\)/,                   find(sel+" li:nth-child(2)").text)  # Though a new EventItem is created, the existing EventItem is checked for the new featuring-Artist, and hence the second one has no featuring Artists. 
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
    # assert_match(/Side channel\b/, find(selector_dl+"dd.item_channel").text)
    assert_match(/Other types\b/, find(selector_dl+"dd.item_channel").text)

    sel = selector_dl+"dd.item_event ol.list_event_items li:first-child"
    assert_match(/\b#{Regexp.quote(vid_prms[:music_title])}\b/, find(sel).text)
    assert_match(/\bfeaturing Artist.+\bAI\b/i,                 find(sel).text)
    assert_selector sel+" a"

    assert_text vid_prms[:note]
  end
  private :_check_at_show

  test "visiting HaramiVid#index as a guest" do
    visit grid_index_path_helper(HaramiVid, column_names: ["events", "collabs"], max_per_page: 25)
    assert_selector "h1", text: @h1_index

    evt = events(:ev_harami_lucky2023)
    tit_lucky = evt.title(langcode: "en")  # HARAMIchan at LuckyFes 2023
    assert_text "The Proclaimers"  # NOT "Proclaimers, The"
    assert_text tit_lucky  # in "feat. Artists"
    assert_selector CSSGRIDS[:th_events],  text: "Events"
    assert_selector CSSGRIDS[:th_collabs], text: "feat. Artists"

    htmlcapy_hed = page.all(CSSGRIDS[:th_tr])[-1].all('th')[5]
    assert_equal    htmlcapy_hed.text, "Events"
    htmlcapy_evt = page.all(CSSGRIDS[:tb_tr])[-1].all('td')[5]
    htmlcapy_art = page.all(CSSGRIDS[:tb_tr])[-1].all('td')[6]
    tit_exp = sprintf("%s [%s]", tit_lucky, evt.event_group.title(langcode: "en"))
    assert_equal    htmlcapy_evt.text, tit_exp
    assert_includes htmlcapy_evt['innerHTML'], tit_exp
    refute_includes htmlcapy_evt['innerHTML'], "<a"  # link hidden for unauthorized in Events
    assert_includes htmlcapy_art['innerHTML'], "<a"  # link visible to anyone in feat. Artists
  end

  test "edit music timing (and note) at HaramiVid#show" do
    hvid = harami_vids :harami_vid3
    h1_tit = "HARAMIchan-featured Video (2020-10-31) by HARAMIchan"

    # unauthenticated user
    visit harami_vid_path(hvid)
    assert_selector "h1", text: h1_tit   # locale: harami_vid_long: 
    assert_includes trans_titles_in_table.values.flatten, hvid.title_or_alt(langcode: "en", lang_fallback_option: :either)

    trs_css = "section#harami_vids_show_musics table tbody tr td.item_timing"  # <=> XPATH_TD_TIMING (Rails-7.2)
    trs = find_all(trs_css)

    assert_includes hvid.harami_vid_music_assocs, (hvma1=harami_vid_music_assocs(:harami_vid_music_assoc3))  # check fixtures
    assert hvma1.timing.blank?, 'checking fixtures'
    assert_includes hvid.harami_vid_music_assocs, (hvma2=harami_vid_music_assocs(:harami_vid_music_assoc_3_ihojin1))  # check fixtures
    assert_operator 1, :<, hvma2.timing, 'checking fixtures'

    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find('a').text
    assert_raises(Capybara::ElementNotFound){
      trs[0].find('form') }
    assert_equal "0", trs[1].find('a').text  # When timing is nil, a significant text (of "0" as opposed to "00:00") is displayed so that <a> tag is valid.

    # for editing note (no web-form for public)
    trs_css_note = "section#harami_vids_show_musics table tbody tr td.item_note"
    trs = find_all(trs_css_note)
    assert_raises(Capybara::ElementNotFound){
      trs[0].find('form') }

    # HaramiEditor
    login_at_root_path(user=@editor_harami)  # defined in test_system_helper.rb

    h1_tit_ed = "HARAMIchan-featured Video [HaramiVid] (2020-10-31) by HARAMIchan"
    visit harami_vid_path(hvid)
    assert_selector "h1", text: h1_tit_ed  # locale: harami_vid_long: 

    trs = find_all(trs_css)
    timing_a_css = 'span.timing-hms a'
    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find(timing_a_css).text
    submit_css = "form input[value=Edit]"

    ### Rails-7.1
    # assert_selector (trs_css+" "+submit_css)
    # trs[0].find(submit_css).click
    # assert_selector (trs_css_note+" "+submit_css)
    assert_selector :xpath, XPATH_TD_TIMING_EDIT 
    assert_selector :xpath, XPATH_TD_NOTE 
    find_all(:xpath, XPATH_TD_TIMING_EDIT)[0].click

    # Edit mode
    with_longer_wait{ assert_selector(trs_css+' input#form_timing') } # This must come BEFORE the assert_raises below because this method would wait (for up to a couple of seconds) till the condition is satisfied as a result of JavaScript's updating the page.
    trs = find_all(trs_css)
    assert_raises(Capybara::ElementNotFound){
      trs[0].find(timing_a_css) }  # In the Edit-mode row, there is no value and link displayed.
    assert trs[1].find(timing_a_css).present?  # Other rows unchanged.

    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find('input#form_timing')["value"]
    assert_equal "commit", trs[0].find('input[type=submit]')["name"]

    trs[0].find('input#form_timing').fill_in with: "-6"
    find(:xpath, XPATH_TD_TIMING+"//input[@type='submit']").click
    #find_all(:xpath, XPATH_TD_TIMING).find('input[type=submit]').click
    
    ### Rails-7.1
    # trs[0].find('input[type=submit]').click

    # After an erroneous submit
    with_longer_wait{ assert_selector trs_css+' div.error_explanation'}  # defined in test_system_helper.rb ; use with CAPYBARA_LONGER_TIMEOUT=3
    trs = find_all(trs_css)
    assert_match(/must be 0 or positive\b/, trs[0].find('div.error_explanation').text)  # => Timing(-6) must be 0 or positive.
    assert_equal("-6", trs[0].find('input#form_timing')["value"], "Negative value should stay in the form field, but...")  # Errror message displayed in the same cell

    assert_equal "Cancel", trs[0].find("a").text  # button-like "Cancel" link
    trs[0].find("a").click

    # Show mode again after "cancelling"
    assert_selector :xpath, XPATH_TD_TIMING_EDIT
    ### Rails-7.1
    # assert_selector (trs_css+" "+submit_css)
    trs = find_all(trs_css)
    assert_selector "h1", text: h1_tit_ed  # locale: harami_vid_long: 
    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find(timing_a_css).text, "value should be reverted back, but..."
    ### Rails-7.1
    # trs[0].find(submit_css).click
    find_all(:xpath, XPATH_TD_TIMING_EDIT)[0].click

    # Edit mode
    assert_selector trs_css+' input#form_timing'
    trs = find_all(trs_css)
    assert_equal sec2hms_or_ms(hvma2.timing), trs[0].find('input#form_timing')["value"]
    trs[0].find('input#form_timing').fill_in with: "72"
    find(:xpath, XPATH_TD_TIMING+"//input[@type='submit']").click
    ### Rails-7.1
    # trs[0].find('input[type=submit]').click

    # Show mode again after successful submission
    #   At the top, "Success" message is displayed... (but nobody would notice it!)
    assert_selector :xpath, XPATH_TD_TIMING_EDIT
    ### Rails-7.1
    # assert_selector (trs_css+" "+submit_css)
    trs = find_all(trs_css)
    assert_selector "h1", text: h1_tit_ed  # locale: harami_vid_long: 
    assert_equal "01:12", trs[0].find(timing_a_css).text, "value should be updated, but..."
    ### Rails-7.1 (it is already tested above in Rails-7.2)
    # assert_equal "Edit", trs[0].find(submit_css)["value"]

    pla_hvid = places(:perth_aus)
    hvid.update!(place: pla_hvid)  # Place: Perth, Australia

    hvid2 = harami_vids(:harami_vid2)
    assert hvid2.place
    refute hvid2.place.unknown?
    page.find('input#pid_edit_harami_vid_with_ref').fill_in with: hvid2.uri  # This is unique!
    url = edit_harami_vid_url(hvid, params: {reference_harami_vid_kwd: hvid2.uri})
    urlmod = url.sub(/\?locale=en&/, "?")  # locale does something wrong...
    css = 'a#href_edit_harami_vid_with_ref'
    assert_selector css
    assert_selector sprintf('%s[href="%s"]', css, urlmod)

    page.find(css).click
    assert_selector "div.alert"
    assert_match(/Edit with the reference HaramiVid of pID=#{hvid.id}/, page.find_all("div.alert")[0]['innerHTML'])
    assert_match(/Editing Harami Vid \(ID=#{hvid2.id}\)/, page.find_all("h1")[0]['innerHTML'])
    css = 'section#sec_primary_input select#harami_vid_place\.prefecture_id\.country_id option[selected="selected"]'
    assert_selector css
    refute_equal pla_hvid.country.id.to_s, (res=page.find(css))["value"], "Selected=#{res['outerHTML']}"  # For edit, if a significant Place is already defined, it should not be updated (by contrast, in "new", a significant Place is propagated, as tested in harami_vids_controller_test.rb).
    assert_equal hvid2.place.country.id.to_s, (res=page.find(css))["value"], "Selected=#{res['outerHTML']}"  # For edit, if a significant Place is already defined, it should not be updated.
    css = 'section#sec_primary_input select#harami_vid_place optgroup option[selected="selected"]'
    assert_equal hvid2.place.id.to_s, (res=page.find(css))["value"], "Selected=#{res['outerHTML']}"  # For edit, if a significant Place is already defined, it should not be updated.
  end

  test "visiting-HaramiVid#edit" do
    create_anchoring_button_txt = "Create Anchoring"

    # Prep
    tit2 = "test-#{__method__}-2"
    date_str = "2025-01-23"
    hvid2 = HaramiVid.create_basic!(title: tit2, langcode: "en", uri: "http://youtu.be/2dummytest2", release_date: Date.parse(date_str))
    mu = musics(:music1)
    hvid2.musics << mu
    # with an associated Music with nil timing; no associated EventItem
    #hvid2.harami_vid_music_assocs.find_by(music: mu).update!(timing: 15)
    #assert_nil hvid2.timing(mu), 'sanity check'

    login_at_root_path(@editor_harami)  # defined in test_system_helper.rb

    click_on @h1_index, match: :first
    assert_selector "h1", text: @h1_index

    ## Test of CRUD of Anchoring in Show
    assert_anchoring_crud_in_show(hvid2, h1_title=date_str, skip_login: true)  # defined in test_system_helper.rb

    ## move to Edit
    visit edit_harami_vid_path(hvid2)
    assert_text tit2

    css_td = "table#music_table_for_hrami_vid tbody tr td.item_timing"
    ### Rails-7.1
    # css_edit = css_td + " input[type=submit][value=Edit]"
    # find(css_edit).click
    find(:xpath, XPATH_TD_TIMING_EDIT).click  # XPATH for Rails-7.2 View

    css_form_timing = css_td+" input[name=form_timing]"
    with_longer_wait{ assert_selector css_form_timing }
    find(css_form_timing).fill_in with: 75
    find(css_td+" input[type=submit][value=Submit]").click

    assert_selector(:xpath, XPATH_TD_TIMING_EDIT)
    ### Rails-7.1
    # assert_selector css_edit
    exp = "01:15 Edit"  # Rails-7.2 (<button>);  "01:15" in Rails-7.1 (<input>)
    assert_equal exp, (lines=find(css_td).text.split("\n")).first.strip, "Video timing should have been updated, but..."
    #assert_includes        lines[1].strip, "uccessfully updated"
    assert_includes        lines.join(" ").strip, "uccessfully updated"  # There is also a warning message: "Please make sure to add an Event(Item)."

    fill_in "Video length", with: "1:12"

    selbox_text = "Additional Event"
    selbox = find_field(selbox_text)
    select selbox.find('option:last-child').text, from: selbox_text

    click_on @update_haramivid_button, match: :first

    assert_selector "h1", text: "HARAMIchan-featured Video"
    assert_text tit2
    css_evit = "section#harami_vids_show_unique_parameters dd.item_event li ol li a"
    assert_selector css_evit  # This appears for the first time.
    assert_equal "72.0 (01:12)", find("section.show_unique_parameters dl dd.item_duration").text.strip

    # EventItem page
    find_all(css_evit).first.click
    assert_selector "h1", text: "EventItem: "
    assert_text tit2  # HaramiVid should be included in a table.
  end

  # test "destroying a Harami vid" do
  #   visit harami_vids_url
  #   page.accept_confirm do
  #     click_on "Destroy", match: :first
  #   end

  #   assert_text "Harami vid was successfully destroyed"
  # end
end
