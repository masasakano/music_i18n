# coding: utf-8
require "application_system_test_case"

class ChannelsTest < ApplicationSystemTestCase
  setup do
    @record = @channel1 = @channel = channels(:one)
    @model_underscore = @record.class.name.underscore
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
    @h1_title = "Channels"
    @button_text = {
      create: "Create Channel",
      update: "Update Channel",
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting Channel#index" do
    assert_index_fail_succeed(channels_url, @h1_title, user_fail: nil, user_succeed: @editor_ja)  # defined in test_system_helper.rb
  end

  test "should create Channel" do
    newchan = "New Channel"
    assert_index_fail_succeed(new_channel_url, newchan, user_fail: nil, user_succeed: @moderator_gen)  # defined in test_system_helper.rb

    ## Now logged in as @moderator_gen
    visit channels_url
    assert_selector "h1", text: @h1_title
    css = "div#channels table tr"
    assert_selector css
    n_records_be4 = page.all(css).size - 1
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    click_on "New Channel"

    #page_find_sys(:trans_new, :langcode_radio, model: Channel).choose('English')  # defined in test_system_helper
    ##page.find('input#channel_title').fill_in with: 'Tekitoh'  # This is unique!
    #fill_in "Channel Full Title - romaji", with: "dummy"  # This should be ignored.

    new_title = 'Tekitoh'
    fill_in_new_translations([{ title: new_title, romaji: "tekitou", langcode: "en", is_orig: true },
                              { title: new_title+"-ja", langcode: "ja", is_orig: false }])  # defined in test_system_helper

    #select "HARAMIchan", from: "Channel owner"  # If unknown, "Channel is already taken".  TODO: Test it?
    select "ハラミちゃん", from: "Channel owner"  # Japanese is displayed even in English environment (b/c simple_form default etc)...
    select "Unknown", from: "Channel platform"
    select "Unknown", from: "Channel type"
    new_note = "new-note"
    fill_in_main_note_with(new_note)  # defined in test_system_helper.rb
    refute_nested_forms  # defined in test_system_helper.rb

    click_on @button_text[:create]

    assert_text "Channel was "+(str="successfully created")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb

    mdl2 = record = Channel.last_created
    assert_selector "dd.item_note", text: new_note
    assert_equal new_note,  record.note
    assert_equal new_title,       (tra_en=record.best_translation).title
    assert_equal new_title+"-ja", (tra_ja=record.best_translation(:ja)).title
    assert_equal Translation::KIND_FULL, tra_en.kind
    assert_equal Translation::KIND_FULL, tra_ja.kind

    ## testing switching locale
    assert_equal "en", record.orig_locale
    assert_equal :nil, assert_switch_orig_locale(record, browser_locale=:en, to_locale: nil)  # defined in test_system_helper.rb
    assert_equal :ja,  assert_switch_orig_locale(record, browser_locale=:en, to_locale: :ja)  # defined in test_system_helper.rb
    record.reload
    assert_equal new_title+"-ja", record.best_translation.title
    assert_equal :en,  assert_switch_orig_locale(record, browser_locale=:en, to_locale: :en)  # defined in test_system_helper.rb
    xpath_ko = switch_orig_locale(:ko)  # should fail to switch b/c no :ja Translation (but no exception or assertion failure)
    refute_selector :xpath, xpath_ko

    click_on "Back", match: :first

    n_records = page.all("div#channels table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update Channel" do
    visit channel_url(mdl2, locale: I18n.locale)
    assert_selector "h1", text: "Channel:"
    assert_selector "h1", text: new_title

    click_on "Edit this Channel", match: :first
    assert_selector "h1", text: "Editing Channel"

    fill_in "Note", with: (note2="something_else")
    refute_nested_forms  # defined in test_system_helper.rb

    click_on @button_text[:update]

    assert_text "Channel was "+(str="successfully updated")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    assert_selector "h1", text: new_title

    # Confirming the record has been updated.
    record.reload
    assert_equal note2, record.note

    ## test "should destroy Channel" do

    #visit channel_url(mdl2, locale: I18n.locale)
    #assert_selector "h1", text: "Channel:"
    #assert_match(/\AChannel:/, page.find("h1").text)

    # xp = "div.link-edit-destroy form.button_to button.destroy_link"
    xpath = assert_find_destroy_button  # defined in test_system_helper.rb
    assert_difference("Channel.count", -1){
      assert_destroy_with_text(find(:xpath, xpath), "Channel", just_click: true, chk_flash: true)  # defined in test_system_helper.rb  # This asserts and closes the flash window.
    }

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channels table tr").size - 1
    assert_equal(n_records_be4, n_records)

  end

#  test "CRUD of anchoring for Channel" do
#    channel = channels(:channel_kohmi_youtube_main)
#
#    ## Test of CRUD of Anchoring in Show for public
#    assert_anchoring_crud_in_show(@event, h1_title=channel.title_or_alt(langcode: :en), skip_login: true, locale: :en, no_edit: true)  # defined in test_system_helper.rb
#
#    login_at_root_path(@moderator)  # defined in test_system_helper.rb
#
#    visit channel_path(channel, locale: :en)
#    assert_selector "h1", text: channel.title(langcode: :en)
#    h1_title = find("h1").text
#
#    ## Test of CRUD of Anchoring in Show
#    assert_anchoring_crud_in_show(channel, h1_title, skip_login: true)  # defined in test_system_helper.rb
#  end
end
