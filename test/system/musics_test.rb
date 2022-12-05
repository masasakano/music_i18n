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
    assert_selector 'div#div_select_prefecture', visible: :hidden

    # Music#new page
    assert_selector "h1", text: "New Music"

    fill_autocomplete('Associated Artist name', with: 'RCサクセ', select: 'RCサクセション')  # defined in test_helper.rb
    assert_equal 'RCサクセション', find_field('Artist name').value

    select_form_eh = page.find('form div.field select#music_engage_hows')
    select_form_eh.select('Arranger')
    select_form_eh.select('Conductor')

    # label_str = I18n.t('layouts.new_translations.model_language', model: 'Music')
    # find_field(label_str).choose('English')  ## Does not work b/c the label is just a <span>!
    page.find('form div.field.radio_langcode').choose('English')

    label_str = I18n.t('layouts.new_translations.title', model: 'Music')
    find_field(label_str, match: :first).fill_in with: 'Tekitoh'

    assert     find_field('Country')
    assert_selector    'form div#div_select_country'
    assert_selector    'form div#div_select_prefecture', visible: :hidden
    assert_no_selector 'form div#div_select_prefecture'  # display: none
    assert_no_selector 'form div#div_select_place'       # display: none

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    assert_selector    'form div#div_select_prefecture'  # Now JS made it appear
    assert     find_field('Prefecture')                  # Now JS made it appear

    ##select('XXX',  from: 'Genre')
    find_field('Year').fill_in with: '2001'

    click_on "Create Music"

    assert_text "Music was successfully created"
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
