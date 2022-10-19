require "application_system_test_case"

class PlacesTest < ApplicationSystemTestCase
  setup do
    #@place = places(:one)
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

    # label_str = I18n.t('layouts.new_translations.model_language', model: 'Place')
    # find_field(label_str).choose('English')  ## Does not work b/c the label is just a <span>!
    page.find('form div.field.radio_langcode').choose('English')

    assert     find_field('Country')
    assert_selector    'form div#div_select_country', text: "Country"
    ###assert_selector    'form div#div_select_country label', text: "World"
    assert_selector    'form div#div_select_prefecture'  # It is NOT:  "visible: :hidden"

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    select('Japan',  from: 'Country')
    click_on "Create Place"

    assert_equal path2place_index, current_path, 'Should be on Index path after erroneous input.'
    assert_text "AltTitle must exist"
    assert_text "Prefecture must exist"

    select('Japan',  from: 'Country')
    #puts "DEBUG-0x:html="+page.html
    #puts "DEBUG-0y:selectbox-List-options="+page.find('select#place_prefecture').text.inspect
    #select('Kagawa', from: 'Prefecture')  ## For some reason, this does not work...
    page.find('select#place_prefecture').select('Kagawa')
    #page.find('select#place_prefecture').find(:option, 'Kagawa').select_option  # This works! (more verbose way)

    label_str = I18n.t('layouts.new_translations.title', model: 'Place')
    find_field(label_str, match: :first).fill_in with: 'Tekitoh'
    page.find('form input#place_alt_title').fill_in with: 'MyNew_place_Alt2'

    find_field('Note').fill_in with: 'Note place 2-A'
    click_on "Create Place"

    assert_text "Place was successfully created", maximum: 1
  end

  #test "updating a Place" do
  #  visit places_url
  #  click_on "Edit", match: :first

  #  fill_in "Note", with: @place.note
  #  fill_in "Prefecture", with: @place.prefecture_id
  #  click_on "Update Place"

  #  assert_text "Place was successfully updated"
  #  click_on "Back"
  #end

  #test "destroying a Place" do
  #  visit places_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Place was successfully destroyed"
  #end
end
