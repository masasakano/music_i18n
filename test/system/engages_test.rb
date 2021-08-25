require "application_system_test_case"

class EngagesTest < ApplicationSystemTestCase
  setup do
    @engage = engages(:one)
  end

  test "visiting the index" do
    visit engages_url
    assert_selector "h1", text: "Engages"
  end

  test "creating a Engage" do
    visit engages_url
    click_on "New Engage"

    fill_in "Artist", with: @engage.artist_id
    fill_in "Contribution", with: @engage.contribution
    fill_in "Music", with: @engage.music_id
    fill_in "Note", with: @engage.note
    fill_in "Year", with: @engage.year
    click_on "Create Engage"

    assert_text "Engage was successfully created"
    click_on "Back"
  end

  test "updating a Engage" do
    visit engages_url
    click_on "Edit", match: :first

    fill_in "Artist", with: @engage.artist_id
    fill_in "Contribution", with: @engage.contribution
    fill_in "Music", with: @engage.music_id
    fill_in "Note", with: @engage.note
    fill_in "Year", with: @engage.year
    click_on "Update Engage"

    assert_text "Engage was successfully updated"
    click_on "Back"
  end

  test "destroying a Engage" do
    visit engages_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Engage was successfully destroyed"
  end
end
