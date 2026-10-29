# coding: utf-8
require "application_system_test_case"

class ChannelOwnersTest < ApplicationSystemTestCase
  setup do
    @record = @channel_owner = channel_owners(:channel_owner_saki_kubota)
    @model_underscore = @record.class.name.underscore
    @channel_owner2= channel_owners(:channel_owner_haramichan)
    @artist = artists(:artist_saki_kubota)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Channel Owners"
    @button_text = {
      create: "Create Channel owner",
      update: "Update Channel owner",
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting ChannelOwner#index" do
    assert_index_fail_succeed(channel_owners_url, @h1_title, user_fail: @translator, user_succeed: @editor_ja)  # defined in test_system_helper.rb
  end

  test "should create channel owner" do
    ## fail to visit directly new ChannelOwner page if unauthorized
    newchan = "New Channel Owner"
    assert_index_fail_succeed(new_channel_owner_url, newchan, user_fail: @translator, user_succeed: @moderator_gen)  # defined in test_system_helper.rb

    ## Now logged in as @moderator_gen
    visit channel_owners_url
    assert_selector "h1", text: @h1_title
    css = "div#channel_owners table tr"
    assert_selector css
    n_records_be4 = page.all(css).size - 1
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    click_on "New ChannelOwner"

    #page_find_sys(:trans_new, :langcode_radio, model: ChannelOwner).choose('English')  # defined in test_system_helper
    ##page.find('input#channel_owner_title').fill_in with: 'Tekitoh'  # This is unique!
    #fill_in "ChannelOwner Full Title - romaji", with: "dummy"  # This should be ignored.

    # fill_in_new_translations([{ title: "dummy" }])  # defined in test_system_helper  # "dummy" is now not required when themselves=true!
    assert_selector "div.#{@model_underscore}_note"
    check "Themselves?"
    fill_in_main_note_with("new-note")  # defined in test_system_helper.rb

    # txt_saki_kubota = sprintf("%s [%s] [ID=%s]", @artist.title, 'ja', @artist.id) #  "Saki Kubota' in translations.yml
    fill_autocomplete('Artist name', with: 'Lennon') # select: txt_saki_kubota)  # defined in test_helper.rb
    # NOTE: there should be only one candidate in fixtures (tested below).

    click_on @button_text[:create]

    assert_text "ChannelOwner was successfully created"
    assert_equal 'John Lennon',  page.find('table#all_registered_translations_channel_owner tr.lc_en td.trans_title').text

    ## testing failing in switching locale
    mdl2 = record = ChannelOwner.last_created
    assert_equal record.artist.orig_locale, record.orig_locale
    assert_equal "en", record.orig_locale, "this depends on Artist's orig_locale in fixtures..."

    css_table = "table." + Consts::Csses::Layouts::ALL_REGISTERED_TRANSLATIONS
    assert_selector css_table
    xpath = switch_orig_locale(to_locale=nil)  # defined in test_system_helper.rb
    assert_equal String, xpath.class, "should be XPath as it should have failed to find the link to update orig_locale, but..."
    refute_selector :xpath, xpath
    css = css_table + " tbody td.trans_edit"
    refute_selector css+" a."+Consts::Csses::Layouts::EDIT_LINK  # Edit link for Translaiton should not exist
    # refute_selector css   # Edit cell itself should not exist  ## => not yet implemented, leaving blank cells

    synced_artist = record.artist
    assert_equal synced_artist, record.translations.first.sync_parent.translatable, "Translation should be synced to the parent Artist, but..."
    artist_candidates = Artist.select_regex(:titles, /Lennon/)
    assert_equal 1,             artist_candidates.size, "fixture testing to confirm there is only one Artist Lennon, but..."
    assert_equal synced_artist, artist_candidates.first

    click_on "Back to Index", match: :first

    n_records = page.all("div#channel_owners table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update ChannelOwner"
    visit channel_owner_url(mdl2, locale: I18n.locale)
    click_on "Edit this ChannelOwner", match: :first

    assert_selector "h1", text: "Editing Channel Owner"

    uncheck "Themselves?"  # deassociate Artist
    new_note = "something_else"
    fill_in_main_note_with(new_note)  # defined in test_system_helper.rb
    click_on @button_text[:update]

    assert_text "ChannelOwner was "+(str="successfully updated")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb

    # Confirming the record has been updated.
    assert_selector "dd.item_note", text: new_note
    record.reload
    assert_equal new_note, record.note
    assert_nil       record.artist_id
    refute_predicate record.translations.first, :sync_parent

    ## testing switching locale
    assert_equal "en", record.orig_locale, "orig_locale should not have changed, but..."
    assert_equal :with_confirm, assert_switch_orig_locale(record, browser_locale=:en, to_locale: nil)  # defined in test_system_helper.rb
    assert assert_switch_orig_locale(record, browser_locale=:en, to_locale: :en)  # defined in test_system_helper.rb
    xpath_ko = switch_orig_locale(:ko)  # should fail to switch b/c no :ja Translation (but no exception or assertion failure)
    refute_selector :xpath, xpath_ko

    # Re-editing to associate the same Artist
    assert_text "Edit this ChannelOwner"
    click_on "Edit this ChannelOwner", match: :first

    assert_selector "div.#{@model_underscore}_note"
    check "Themselves?"

    fill_autocomplete('Artist name', with: 'Lennon')  # defined in test_helper.rb

    new_note2 = "edited twice"
    fill_in_main_note_with(new_note2)  # defined in test_system_helper.rb

    click_on @button_text[:update]

    assert_text "ChannelOwner was "+(str="successfully updated")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb

    # Confirming the record has been updated.
    assert_selector "dd.item_note", text: new_note2
    record.reload
    assert_equal new_note2, record.note
    assert_equal synced_artist, record.artist
    assert_predicate            record.translations.first, :sync_parent
    assert_equal synced_artist, record.translations.first.sync_parent.translatable

    #click_on "Back", match: :first

    ## test "should destroy ChannelOwner" do  # here destroying ChannelOwner having an associated parent Artist

    #visit channel_owner_url(mdl2, locale: I18n.locale)
    #assert_selector "h1", text: "Channel Owner:"
    #assert_match(/\AChannel\s*Owner:/, page.find("h1").text)

    xpath = assert_find_destroy_button  # defined in test_system_helper.rb
    assert_destroy_with_text(xpath, "ChannelOwner")  # defined in test_system_helper.rb

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channel_owners table tr").size - 1
    assert_equal(n_records_be4, n_records)

  end
end
