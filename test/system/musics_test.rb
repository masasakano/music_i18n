# coding: utf-8
require "application_system_test_case"

class MusicsTest < ApplicationSystemTestCase
  setup do
    #@music = musics(:one)
    @moderator = users(:user_moderator_general_ja)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index and then new" do
    # Music#index
    visit musics_url
    assert_selector "h1", text: "Musics"
    assert_no_selector 'form.button_to'  # No button if not logged-in.

    n_trs0 = page.find_all("tr").size

    genre_word = 'Classic'
    genre = Genre.find_by_regex(:title, /^#{genre_word}$/)
    assert genre.id  # sanity check (checking fixtures)

    assert (classic_mus=Music.where(genre_id: genre.id)).exists?, "sanity check"  # At least one Classic music exists

    select(genre_word,  from: 'Genre')  # t(:Genre)
    click_on "Apply"

    mu_classic = classic_mus.first
    one_title = mu_classic.title_or_alt(langcode: "en", lang_fallback_option: :either)
    assert one_title.present?, "sanity check"

    assert_selector "h1", text: "Musics"
    assert_text one_title

    n_trs_classic = page.find_all("tr").size
    assert_operator n_trs0, :>, n_trs_classic, "The number of table rows should have (greatly) decreased, but..."

    # Reset
    click_on "Reset"
    
    n_trs1 = page.find_all("tr").size
    assert_equal n_trs0, n_trs1, "The number of table rows should be reset, but..."

    ########### goes to HaramiVid#show by public

    title_ja = "ストーリー"
    mutmp = musics(:music_story)
    assert_equal title_ja, mutmp.title(langcode: "ja"), "sanity check of fixtures"
    title_en = mutmp.title(langcode: "en")

    fill_autocomplete('#musics_grid_title_ja', use_find: true, with: 'ストー', select: title_ja)  # defined in test_helper.rb
    click_on "Apply"

    assert_text title_ja
    assert_selector "td", text: title_ja
    n_trs_story = page.find_all("tr").size
    assert_operator n_trs0, :>, n_trs_story, "The number of table rows should have (greatly) decreased, but...: "+page.find('p.pagenation_stats')['innerHTML']

    xpath_music_index_row_of_story = sprintf("//table[contains(@class, 'datagrid-table')]/tbody/tr[td[contains(@data-column, '%s') and text()='%s']]", "title_ja", title_ja )
    # assert_selector :xpath, "//table[contains(@class, 'musics_grid')]/tbody/tr"
    # assert_selector :xpath, "//table[contains(@class, 'musics_grid')]/tbody/tr[1]/td"
    # assert_selector :xpath, "//table[contains(@class, 'musics_grid')]/tbody/tr[td[contains(@class, 'title_ja')]]"
    # assert_selector :xpath, "//table[contains(@class, 'musics_grid')]/tbody/tr[td[@class='title_ja']]"
    assert_selector :xpath, xpath_music_index_row_of_story
    assert_selector :xpath, xpath_music_index_row_of_story
    trow = find(:xpath, xpath_music_index_row_of_story)

    sub_xpath_to_detail = "//td[contains(@class, 'actions')]"
    assert_equal 1, trow.find_all(:xpath, sub_xpath_to_detail).size
    trow.find(:xpath, sub_xpath_to_detail+"//a").click

    ########### HaramiVid#show by public

    assert_selector "h1", text: title_en

    art = mutmp.artists.first
    assert (art_tit_ja=art.title(langcode: "ja")).present?, "sanity check."
    refute art.alt_title(langcode: "ja").present?, "sanity check."

    xpath_music_table_row1 = '//*[@id="sec_artists_by"]//table/tbody/tr[1]'
    xpath_music_table_tit_ja = xpath_music_table_row1
    assert_selector(:xpath, xpath_music_table_tit_ja + "/td[1]", text: art_tit_ja)
    cell_str = find(:xpath, xpath_music_table_tit_ja + "/td[2]").text  # ja-alt_title
    assert_equal "", cell_str

    #/html/body/div[5]/table/tbody/tr[5]/td[1]
    #.datagrid > tbody:nth-child(2) > tr:nth-child(5) > td:nth-child(1)
    #html body div#body_main table.datagrid.musics_grid tbody tr td.title_ja
    #html body div#body_main table.datagrid.musics_grid tbody tr td.actions a
    #  • //div[@id="ABC"]//a[text()='Click Me'] (Note the multiple double forward slashes!)

     ########### HaramiVid#new

    visit new_user_session_path
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "HARAMIchan"

    # Music#index
    visit musics_url
    assert_selector "h1", text: "Musics"
    click_on "Create New Music"

    # Test of dropdown-menu
    assert_selector 'div#div_select_country', text: "Country"
    #assert_selector 'div#div_select_prefecture', visible: :hidden
    assert_selector 'div#div_select_place div.form-group.music_place', visible: :hidden

    # Music#new page
    assert_selector "h1", text: "New Music"

    fill_autocomplete('Associated Artist name', with: 'RCサクセ', select: 'RCサクセション')  # defined in test_helper.rb
    assert_equal 'RCサクセション', find_field('Artist name').value

    # select_form_eh = page.find('form div.field select#music_engage_hows')
    # select_form_eh.select('Arranger')
    # select_form_eh.select('Conductor')
    check_form_eh = page.find('form fieldset.form-group.music_engage_hows')
    # html body div#body_main section#sec_primary form#new_music.simple_form.new_music section#sec_primary_input div.register_assoc_artist div.register_assoc_artist_field fieldset.form-group.check_boxes.required.music_engage_hows div.inline input#music_engage_hows_77.form-check-input.check_boxes.required
    check('Arranger')
    check('Conductor')

    # label_str = I18n.t('layouts.new_translations.model_language', model: 'Music')
    # find_field(label_str).choose('English')  ## Does not work b/c the label is just a <span>!
    # page.find(PAGECSS[:new_trans_lang_radios]).choose('English')  # defined in test_helper.rb  # only for old-fashioned forms
    page.find("section#form_edit_translation fieldset.form-group.radio_buttons.music_langcode").choose('English')  # for siple_form

    tit1 = 'Tekitoh___1'
    fill_in_new_title_with(Music, tit1)  # defined in test_system_helper.rb

    assert     find_field('Country')
    assert_selector    'form div#div_select_country'
    #assert_selector    'form div#div_select_prefecture', visible: :hidden
    #assert_no_selector 'form div#div_select_prefecture'  # display: none
    #assert_no_selector 'form div#div_select_place'       # display: none  # only for old-fashioned forms
    assert_no_selector 'div#div_select_place div.form-group.music_place' ## , visible: :hidden (for CSS display: none)  # for siple_form

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    assert_selector    'form div#div_select_prefecture'  # Now JS made it appear
    assert     find_field('Prefecture')                  # Now JS made it appear

    # select('Modern instrumental',  from: 'Genre')
    find_field(I18n.t('Year_Title', locale: "en")).fill_in with: '1250'  # 'Year'; see /app/views/musics/_form.html.erb

    click_on "Create Music"

    assert_text "Music was successfully created"

    click_on "Back to Index", match: :first  # there may be 2 matches, which would raise Capybara::Ambiguous

    assert_selector "h1", text: "Musics"
    assert_equal n_trs0+1, page.find_all("tr").size, "The number of table rows should have increased by 1, but..."

    css_to   = css_grid_input_range(Music, "year", fromto: :to)
    page.find_all('input[type="number"]')[2].fill_in  with: 1200  # the first two are for pID
    page.find(css_to).fill_in  with: 1299
    #find_field("Year", match: :first).fill_in  with: 1200  # not works
    #fill_in "Year", match: :first, with: 1200  # not works
    #fill_in "Year", match: :last,  with: 1299  # not works
    click_on "Apply"

    assert_selector "h1", text: "Musics"
    assert_selector css_to+"[value='1299']"  # The field should keep the input value
    assert_equal 1, (trs=page.find_all("tbody tr")).size, "The number of table-body rows for Musics in the 13th century should be one (just created), but..."
    assert_includes trs[0].text, tit1
#take_screenshot
  end

  #test "updating a Music" do
  #  visit musics_url
  #  click_on "Edit", match: :first

  #  fill_in "Genre", with: @music.genre_id
  #  fill_in "Note", with: @music.note
  #  fill_in "Place", with: @music.place_id
  #  fill_in "Year", with: @music.year
  #  click_on "Update Music"

  #  assert_text "Music was successfully updated"
  #  click_on "Back"
  #end

  #test "destroying a Music" do
  #  visit musics_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Music was successfully destroyed"
  #end
end
