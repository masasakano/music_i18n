# coding: utf-8
require "application_system_test_case"

class ChannelOwnersTest < ApplicationSystemTestCase
  setup do
    @channel_owner = channel_owners(:channel_owner_saki_kubota)
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


  test "visiting the index" do
    visit channel_owners_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @editor_ja.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: @h1_title
    assert_text "Signed in successfully"
  end

  test "should create channel owner" do
    newchan = "New Channel Owner"
    visit channel_owners_url  # direct jump -> fail
    refute_text newchan
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit channel_owners_url
    n_records_be4 = page.all("div#channel_owners table tr").size - 1
    click_on "New ChannelOwner"

    page_find_sys(:trans_new, :langcode_radio, model: ChannelOwner).choose('English')  # defined in helpers/test_system_helper

    page.find('input#channel_owner_title').fill_in with: 'Tekitoh'  # This is unique!

    fill_in "ChannelOwner Full Title - romaji", with: "dummy"  # This should be ignored.
    check "Themselves?"
    fill_in "Note", with: "new-note"

    txt2sel = sprintf("%s [%s] [ID=%s]", @artist.title, 'ja', @artist.id) #  "John Lennon' in translations.yml
    fill_autocomplete('Artist name', with: 'Lennon', select: txt2sel)  # defined in test_helper.rb
    # NOTE: there should be only one candidate (though not tested here).

    click_on "Create Channel owner"

    assert_text "ChannelOwner was successfully created"
    assert_equal 'John Lennon',  page.find('table#all_registered_translations_channel_owner tr.lc_en td.trans_title').text

    click_on "Back"

    n_records = page.all("div#channel_owners table tr").size - 1
    assert_equal(n_records_be4+1, n_records)


    ## "should update ChannelOwner" do
    mdl2 = ChannelOwner.last
    visit channel_owner_url(mdl2)
    click_on "Edit this Channel Owner", match: :first

    assert_selector "h1", text: "Editing Channel Owner"

    fill_in "Note", with: "something_else"
    click_on @button_text[:update]

    assert_text "ChannelOwner was successfully updated"

    # Confirming the record has been updated.
    ### todo...

    click_on "Back"

    ## test "should destroy ChannelOwner" do
    visit channel_owner_url(mdl2)
    assert_match(/\AChannel\s*Owner:/, page.find("h1").text)
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    accept_alert do
      click_on "Destroy", match: :first
    end

    assert_text "ChannelOwner was successfully destroyed"

    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channel_owners table tr").size - 1
    assert_equal(n_records_be4, n_records)

  end
end
