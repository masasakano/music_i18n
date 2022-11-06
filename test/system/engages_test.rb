# coding: utf-8
require "application_system_test_case"

class EngagesTest < ApplicationSystemTestCase
  setup do
    #@engage = engages(:one)
    @engage = engages(:engage_proclaimers_light)
    @artist    = artists(:artist_proclaimers)
    @artist_rc = artists(:artist_rcsuccession)
    @music  = musics(:music_light)
    @moderator = users(:user_moderator_general_ja)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index, visiting edit, add two new ones, revisit edit, destroy both, and confirm in edit" do
    visit new_user_session_path
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "Harami-chan"

    visit engages_url
    assert_selector "h1", text: "Engages"
    sel = "//tr[td//text()[contains(., 'Proclaimers')]]"  # in table
    page.find(:xpath, sel).click_link("Edit", match: :first)

    txt_create_en = "Create a new Engage"
    str = page.find(:css, 'form.button_to.inline_form input')["value"]
    assert_equal txt_create_en, str, "button text is wrong: "+str.inspect

    # Language switcher test for Engage#new
    click_on "日本語", match: :first
    txt_create_ja = "Engage新規作成"
    str = page.find(:css, 'form.button_to.inline_form input')["value"]
    assert_equal txt_create_ja, str, "button text is wrong: "+str.inspect

    # EngageMultiHows#edit page
    click_on txt_create_ja  # "Engage新規作成"

    str = page.find(:css, 'h1').text
    # assert_match(/^New Engage for Music\b/, str, "H1 is wrong: "+str.inspect)  # Japanese text should be set!

    # Language switcher test for Engage#new
    within find("#language_switcher_top") do
      find(".lang_switcher_en").click
      # click_on "English", match: :first  # Equivalent in practice but more ambiguous.
    end

    # Engage#new page
    str = page.find(:css, 'h1').text
    assert_match(/^New Engage for Music\b/, str, "H1 is wrong: "+str.inspect)
    str = page.find(:css, 'form#new_engage input[type="submit"]')["value"]
    assert_equal "Submit", str, "button text is wrong: "+str.inspect
    #assert_selector "h1", text: "New Engage"

    assert_selector "h1", text: @music.title
    assert_equal @music.year, find_field('Year').value.to_i
    fill_autocomplete('Artist name', with: 'RCサクセ', select: 'RCサクセション')  # defined in test_helper.rb
    assert_equal 'RCサクセション', find_field('Artist name').value
    select('Arranger',  from: 'EngageHow')
    select('Conductor', from: 'EngageHow')
    click_on "Submit"

    # Music#show page
    #  assert_text "Engage was successfully created"  # flash message...
    sel = "//tr[td//text()[contains(., 'RCサクセション')]]//td[last()]"  # in "Artists for Music:..." table
    page.find(:xpath, sel).click_link("Edit", match: :first)

    # EngageMultiHows#edit page to delete the newly created 2 Engages
    boxes = page.all('table tbody tr td.checkbox_destroy')
    assert_equal 2, boxes.size
    boxes.each do |eb|
      eb.check()
    end
    click_on "Submit"

    # EngageMultiHows#edit page
    sel = "//tr[td//text()[contains(., 'RCサクセション')]]"  # in "Artists for Music:..." table
    assert_equal 1, page.all(:xpath, sel).size
  end

end

