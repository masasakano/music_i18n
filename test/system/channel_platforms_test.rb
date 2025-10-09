# coding: utf-8
require "application_system_test_case"

class ChannelPlatformsTest < ApplicationSystemTestCase
  setup do
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @channel_platform = channel_platforms(:one)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_gen = users(:user_moderator_general_ja)
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @h1_title = "Channel Platforms"
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting ChannelPlatform#index" do
    visit channel_platforms_url
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @translator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "Channel Platforms"
    #assert_selector "h1", text: "Music-i18n.org for HARAMIchan (ハラミちゃん)"  # Home
    assert_text "Signed in successfully"
  end

  test "should create channel platform" do
    newchan = "Create ChannelPlatform"
    visit new_channel_platform_url  # direct jump -> fail
    refute_text newchan
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_text "Signed in successfully"
    assert_text "New Channel Platform"

    visit channel_platforms_url
    assert_text "Channel Platforms"
    n_records_be4 = page.all("div#channel_platforms table tr").size - 1
    click_on "New ChannelPlatform"

    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#channel_platform_title').fill_in with: 'Tekitoh'  # This is unique!

    fill_in "mname", with: @channel_platform.mname
    fill_in "Note", with: @channel_platform.note
    click_on "Create ChannelPlatform"

    assert_text "prohibited"
    assert_text "Mname has already been taken"
    assert_selector "h1", text: "New Channel Platform"

    ############ Language-related values in the form have disappered after failed save!
    page.find('form div.field.radio_langcode').choose('English')
    page.find('input#channel_platform_title').fill_in with: 'Tekitoh'  # This is unique!
    fill_in "mname", with: "tekitoh"
    click_on "Create ChannelPlatform"

    assert_text "ChannelPlatform was successfully created"
    click_on "Back"

    n_records = page.all("div#channel_platforms table tr").size - 1
    assert_equal(n_records_be4+1, n_records)

    ## "should update ChannelPlatform" do
    mdl2 = ChannelPlatform.last
    visit channel_platform_url(mdl2)
    click_on "Edit this Channel Platform", match: :first

    assert_selector "h1", text: "Editing Channel Platform"

    fill_in "mname", with: "something_else"

    click_on "Update ChannelPlatform"

    assert_text "ChannelPlatform was successfully updated"
    click_on "Back"

    ## test "should destroy ChannelPlatform" do
    visit channel_platform_url(mdl2)
    assert_selector "h1", text: "Channel Platform:"
    assert_match(/\AChannel\s*Platform:/, page.find("h1").text)
if true
    xpath = assert_find_destroy_button  # defined in test_system_helper.rb
    assert_destroy_with_text(xpath, "ChannelPlatform")  # defined in test_system_helper.rb
else
    assert_selector :xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']"

    find(:xpath, "//form[@class='button_to']//input[@type='submit'][@value='Destroy']").click
#    accept_alert do
#      click_on "Destroy", match: :first  # not work as "Destroy" is now in Translation table, too.
#    end

    assert_text "ChannelPlatform was successfully destroyed"
end
    # should be in the Index page
    assert_selector "h1", text: @h1_title  # should be redirected back to index.
    n_records = page.all("div#channel_platforms table tr").size - 1
    assert_equal(n_records_be4, n_records)
  end

end
