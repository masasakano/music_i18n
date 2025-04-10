require "application_system_test_case"

class DomainTitlesTest < ApplicationSystemTestCase
  setup do
    @domain_title = domain_titles(:one)
  end

  test "visiting the index" do
    visit domain_titles_url
    assert_selector "h1", text: "Domain titles"
  end

  test "should create Domain title" do
    visit domain_titles_url
    click_on "New domain title"

    fill_in "Channel owner", with: @domain_title.channel_owner_id
    fill_in "Note", with: @domain_title.note
    fill_in "Note editor", with: @domain_title.note_editor
    fill_in "Site category", with: @domain_title.site_category_id
    fill_in "Weight", with: @domain_title.weight
    click_on "Create Domain title"

    assert_text "Domain title was successfully created"
    click_on "Back"
  end

  test "should update Domain title" do
    visit domain_title_url(@domain_title)
    click_on "Edit this domain title", match: :first

    fill_in "Channel owner", with: @domain_title.channel_owner_id
    fill_in "Note", with: @domain_title.note
    fill_in "Note editor", with: @domain_title.note_editor
    fill_in "Site category", with: @domain_title.site_category_id
    fill_in "Weight", with: @domain_title.weight
    click_on "Update Domain title"

    assert_text "Domain title was successfully updated"
    click_on "Back"
  end

  test "should destroy Domain title" do
    visit domain_title_url(@domain_title)
    click_on "Destroy this domain title", match: :first

    assert_text "DomainTitle was successfully destroyed"
  end
end
