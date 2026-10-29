require "application_system_test_case"

class PlacesTest < ApplicationSystemTestCase
  setup do
    @record = @place = places(:tocho) # places(:one)
    @model_underscore = @record.class.name.underscore
    @moderator = users(:user_moderator_general_ja)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index and then new" do
    ## Gets the sign-in path.
    visit new_user_session_path
    path2signin = current_path

    ## Visits Place#index => redirected to Sign-in
    visit places_url
    assert_no_selector 'div#button_create_new_place'
    assert_equal path2signin, current_path, 'Should have been redirected as normal users cannot see Place#index.'
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "Places"  # should be redirected back to Place#index.

    # Place#index
    path2place_index = current_path
    assert_selector "h1", text: "Places"
    click_on "Create new Place"

    assert_selector "#sec_primary_input div.place_note"  # to ensure most fields have been loaded.

    ## label_str = I18n.t('layouts.new_translations.model_language', model: 'Place')
    ## find_field(label_str).choose('English')  ## Does not work b/c the label is just a <span>!
    #page_find_sys(:trans_new, :langcode_radio, model: Place).choose('English')  # defined in test_system_helper
    ##page.find('form div.field.radio_langcode').choose('English')
    assert_selector 'input#place_translations_attributes_0_is_formal_[checked="checked"]'  # Default is nil
    assert_selector 'input#place_translations_attributes_0_is_official_[checked="checked"]'  # Default is nil
    fill_in_new_translation_single(index: 0, title: nil, langcode: "en", is_formal: true, is_official: true) # defined in test_system_helper.rb

    assert     find_field('Country')
    assert_selector CSSHS[:country_select_div]  # defined in test_helper.rb
    assert_selector CSSHS[:country_select_div]+" label",    text: I18n.t(:Country).capitalize
    assert_selector CSSHS[:prefecture_select_div]+" label", text: I18n.t(:Prefecture).capitalize  # defined in test_helper.rb
    refute_selector CSSHS[:place_select_div]+" label"
    refute_selector CSSHS[:place_select_div]+" select"

    # In Country-select, "World" should be already selected.
    css = CSSHS[:country_option]+'[selected="selected"]'
    assert_selector css
    cntry_unk = Country.unknown
    assert_equal cntry_unk.id.to_s, page.find(css)["value"]
    assert_selector css, text: cntry_unk.title(langcode: :en)

    # checking Prefecture (cascade-)selection
    tit_uk_en = definite_article_to_head(translations(:uk_en).title)
    # tit_tocho = translations(:tocho_en)
    # tit_takamatsu    = translations(:takamatsu_station_en)
    # tit_takamatsu_en = tit_takamatsu.title.strip
    # tit_unk_significant = places(:harami_home_unknown_prefecture_japan).title_or_alt(langcode: :en, lang_fallback_option: :either) 
    assert_field "Country" #, selected: "Unknown"  # should be already selected
    # select "World", from: "Country"
    select "UK", from: "Country"
    assert_selector CSSHS[:prefecture_option], text: "Liverpool"  # Without this, the next "select" may not wait long enough.
    select "Liverpool", from: "Prefecture"
    assert_selector CSSHS[:prefecture_option], text: "UnknownPrefecture"
    refute_selector CSSHS[:prefecture_option], text: "Tokyo"  # should be either hidden (client-side) or completely absent (server-side cascading-dropdown)
    #assert_selector css_place_opt, text: "Unknown"
    ## assert_field "UnknownPlace", checked: true  # should be already selected
    #refute_selector css_place_opt, text: tit_tocho.title
    #refute_selector css_place_opt, text: tit_tocho.alt_title
    #refute_selector css_place_opt, text: tit_unk_significant # New Place candidates for UnknownPrefecture should be set as soon as Country changes, but...

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    ## print "DEBUG: "; p page.find_all("#div_select_prefecture select optgroup").map{_1[:outerHTML]}
    assert_selector CSSHS[:prefecture_option], text: "Kagawa"
    assert_selector CSSHS[:prefecture_option], text: "UnknownPrefecture"
    refute_selector CSSHS[:prefecture_option], text: "Liverpool"  # should be either hidden or not displayed at all
    refute_selector CSSHS[:place_select_div]+" select"  # to ensure Place select does not appear
    select "Kagawa", from: "Prefecture", visible: true

    click_on "Create Place"  # => should fail due to blank title

    assert_text (str="prohibited this")+" Place from being saved"
    flash_text_system_assert(str, type: [:alert], category: :div)  # defined in test_helper.rb
    flash_text_system_assert("must be non-blank", type: [:alert], category: :div)  # defined in test_helper.rb
    #assert_text "AltTitle must exist"   # This would wait.
    # assert_text "Prefecture must exist"  # NOTE: this used to be the case when client-side cascading-dropdown was employed.
    mat, _ = two_prms_redirected_to_fuzzy_locale(path2place_index, act: true, locale: I18n.locale) # defined in test_helper.rb
    assert_match(mat, current_path, "Should be on Index path after erroneous input.")  # NOT "new/" according to Rails convention.
    # assert_equal path2place_index, current_path, 'Should be on Index path after erroneous input.'  # NOT "new/" according to Rails convention.

    assert_selector 'input#place_translations_attributes_0_is_formal_true[checked="checked"]'    # true(Yes) should remain checked
    assert_selector 'input#place_translations_attributes_0_is_official_true[checked="checked"]'  # true(Yes) should remain checked

    css = CSSHS[:prefecture_option]+'[selected="selected"]'
    assert_selector css
    assert_selector css, text: "Kagawa"

    # select('Japan',  from: 'Country')
    # #puts "DEBUG-0x:html="+page.html
    # #puts "DEBUG-0y:selectbox-List-options="+page.find('select#place_prefecture').text.inspect
    # #select('Kagawa', from: 'Prefecture')  ## For some reason, this does not work...
    # page.find('select#place_prefecture').select('Kagawa')
    # #page.find('select#place_prefecture').find(:option, 'Kagawa').select_option  # This works! (more verbose way)

    place_tit = 'Tekitoh77'
    #label_str = I18n.t('layouts.new_translations.title', model: 'Place')
    #find_field(label_str, match: :first).fill_in with: place_tit
    #page.find('form input#place_alt_title').fill_in with: 'MyNew_place_Alt2'
    fill_in_new_translations([{ title: place_tit },
                              { title: 'MyNew_place_Alt2', langcode: "en" }]) # defined in test_system_helper.rb

    fill_in_main_note_with('Note place 2-A')  # defined in test_system_helper.rb
    click_on "Create Place"

    assert_text "Place was "+(str="successfully created") #, maximum: 1  ## After the introduction of Flash-display for Turbo, 2 of them appear. Not ideal.
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    assert_selector "h1", text: place_tit
    assert_selector "dd."+Consts::Csses::Shows::ITEM_NOTE
    css = "dd."+Consts::Csses::Shows::ITEM_PREFIX+"prefecture"
    assert_match(/Kagawa|香川県/, page.find(css).text)

    refute_selector :xpath, xpath_all_translation_table(langcode: "ja")  # defined in test_helper.rb
    refute_selector :xpath, xpath_all_translation_table(langcode: "fr")
    xpath_en = xpath_all_translation_table(langcode: "en")
    assert_selector :xpath, xpath_en   # English Translations only.
    assert_equal 2, all(:xpath, xpath_en).size

    ## testing switching locale
    record = Place.last_created
    assert_equal :with_confirm, assert_switch_orig_locale(record, browser_locale=:en, to_locale: nil)  # defined in test_system_helper.rb
    assert assert_switch_orig_locale(record, browser_locale=:en, to_locale: :en)  # defined in test_system_helper.rb
    xpath_ja = switch_orig_locale(:ja)  # should fail to switch b/c no :ja Translation (but no exception or assertion failure)
    refute_selector :xpath, xpath_ja

    ## Edit and :update
    css = "."+Consts::Csses::Layouts::EDIT_LINK_PRIMARY
    assert_selector css, text: "Edit"
    page.find(css).click  # click_on("Edit") results in Capybara::Ambiguous

    assert_selector "h1", text: "Editing Place"

    css = CSSHS[:prefecture_option]+'[selected="selected"]'
    assert_selector css
    assert_selector css, text: "Kagawa"
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    # print "DEBUG:pref: "; puts find_all(CSSHS[:prefecture_option]).map{_1[:innerHTML]}.join("\n")
    select "Simane", from: "Prefecture", visible: true  # "Simane" is alt_title, whereas title is "Shimane"
    note2add = "Provincial change made."
    fill_in_main_note_with(note2add)  # defined in test_system_helper.rb

    click_on "Update Place"

    assert_text (msg="Place was successfully updated") #, maximum: 1
    flash_regex_assert(Regexp.new(msg), type: [:success, :notice], system_test: true)
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    assert_text note2add
    css = "dd."+Consts::Csses::Shows::ITEM_PREFIX+"prefecture"
    assert_match(/Sh?imane|島根県/, page.find(css).text)
    assert_selector "dd."+Consts::Csses::Shows::ITEM_NOTE, text: note2add
  end

  test "CRUD of anchoring for Place" do
    place = places(:tocho)

    #### Place-show is inaccessible for the public.
    ## Test of CRUD of Anchoring in Show for public
    #assert_anchoring_crud_in_show(place, h1_title=place.title_or_alt(langcode: :en, lang_fallback_option: :either), skip_login: true, locale: :en, no_edit: true)  # defined in test_system_helper.rb

    login_at_root_path(@moderator)  # defined in test_system_helper.rb

    visit place_path(place, locale: :en)
    assert_selector "h1", text: place.title # H1 for Place is in the original language.
    h1_title = find("h1").text

    ## Test of CRUD of Anchoring in Show
    assert_anchoring_crud_in_show(place, h1_title, skip_login: true)  # defined in test_system_helper.rb
  end

  #test "destroying a Place" do
  #  visit places_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Place was successfully destroyed"
  #end
end
