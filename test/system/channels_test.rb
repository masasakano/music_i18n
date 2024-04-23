# coding: utf-8
require "application_system_test_case"

class ChannelsTest < ApplicationSystemTestCase
  setup do
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

  test "visiting the index" do
    visit channels_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @editor_ja.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: @h1_title
    assert_text "Signed in successfully"
  end

  test "should create channel" do
    newchan = "New Channel"
    visit channels_url  # direct jump -> fail
    refute_text newchan
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit channels_url
    n_records_be4 = page.all("div#channels table tr").size - 1
    click_on "New Channel"

    page_find_sys(:trans_new, :langcode_radio, model: Channel).choose('English')  # defined in helpers/test_system_helper

    page.find('input#channel_title').fill_in with: 'Tekitoh'  # This is unique!

    fill_in "Channel Full Title - romaji", with: "dummy"  # This should be ignored.
    select "HARAMIchan", from: "Channel owner"  # If unknown, "Channel is already taken".  TODO: Test it?
    select "Unknown", from: "Channel platform"
    select "Unknown", from: "Channel type"
    fill_in "Note", with: "new-note"

    click_on "Create Channel"

    assert_text "Channel was successfully created"

    click_on "Back"

    n_records = page.all("div#channels table tr").size - 1
    assert_equal(n_records_be4+1, n_records)


    ## "should update Channel" do
    mdl2 = Channel.last
    visit channel_url(mdl2)
    click_on "Edit this Channel", match: :first

    assert_selector "h1", text: "Editing Channel"

    fill_in "Note", with: "something_else"
    click_on @button_text[:update]

    assert_text "Channel was successfully updated"

    # Confirming the record has been updated.
    ### todo...

    click_on "Back"

    ## test "should destroy Channel" do
    visit channel_url(mdl2)
    assert_match(/\AChannel:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    accept_alert do
      click_on "Destroy", match: :first
    end

    assert_text "Channel was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channels table tr").size - 1
    assert_equal(n_records_be4, n_records)

  end
end
