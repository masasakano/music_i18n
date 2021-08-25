require "application_system_test_case"

class HaramiVidsTest < ApplicationSystemTestCase
  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @sysadmin = users(:user_sysadmin)
  end

  test "visiting the index" do
    visit new_user_session_path
    fill_in "Email", with: @sysadmin.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    # assert_response :redirect  # NoMethodError
    assert_selector "h1", text: "Harami-chan"

    visit harami_vids_url
    assert_selector "h1", text: "Harami Vids"

    click_on "New Harami Vid"
    assert_selector 'div#div_select_country', text: "Country"
    assert_selector 'div#div_select_prefecture', visible: :hidden  ## The captured image somehow shows Prefecture, whereas an acutal browser doesn't. Something to do with JavaScript? Strange...
    #assert_equal 'field', css_select('div#div_select_prefecture').first #.attributes['display'].value # class="field"
    
  #   assert_text "Harami vid was successfully created"

    #fill_in "Duration", with: @harami_vid.duration
    #fill_in "Date", with: @harami_vid.date
    #check "Flag by harami" if @harami_vid.flag_by_harami
    #fill_in "Note", with: @harami_vid.note
    #assert_selector "h1", text: "Harami Vids"
  end

  # test "creating a Harami vid" do
  #   visit harami_vids_url
  #   click_on "New Harami Vid"

  #   fill_in "Date", with: @harami_vid.date
  #   fill_in "Duration", with: @harami_vid.duration
  #   check "Flag by harami" if @harami_vid.flag_by_harami
  #   fill_in "Note", with: @harami_vid.note
  #   fill_in "Place", with: @harami_vid.place_id
  #   fill_in "Uri", with: @harami_vid.uri
  #   fill_in "Uri playlist en", with: @harami_vid.uri_playlist_en
  #   fill_in "Uri playlist ja", with: @harami_vid.uri_playlist_ja
  #   click_on "Create Harami vid"

  #   assert_text "Harami vid was successfully created"
  #   click_on "Back"
  # end

  # test "updating a Harami vid" do
  #   visit harami_vids_url
  #   click_on "Edit", match: :first

  #   fill_in "Date", with: @harami_vid.date
  #   fill_in "Duration", with: @harami_vid.duration
  #   check "Flag by harami" if @harami_vid.flag_by_harami
  #   fill_in "Note", with: @harami_vid.note
  #   fill_in "Place", with: @harami_vid.place_id
  #   fill_in "Uri", with: @harami_vid.uri
  #   fill_in "Uri playlist en", with: @harami_vid.uri_playlist_en
  #   fill_in "Uri playlist ja", with: @harami_vid.uri_playlist_ja
  #   click_on "Update Harami vid"

  #   assert_text "Harami vid was successfully updated"
  #   click_on "Back"
  # end

  # test "destroying a Harami vid" do
  #   visit harami_vids_url
  #   page.accept_confirm do
  #     click_on "Destroy", match: :first
  #   end

  #   assert_text "Harami vid was successfully destroyed"
  # end
end
