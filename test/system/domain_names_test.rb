require "application_system_test_case"

class DomainNamesTest < ApplicationSystemTestCase
  setup do
    @domain_name = domain_names(:one)
  end

  test "visiting the index" do
    visit domain_names_url
    assert_selector "h1", text: "Domain names"
  end

  test "should create domain name" do
    visit domain_names_url
    click_on "New domain name"

    fill_in "Channel owner", with: @domain_name.channel_owner_id
    fill_in "Note", with: @domain_name.note
    fill_in "Note editor", with: @domain_name.note_editor
    fill_in "Site category", with: @domain_name.site_category_id
    fill_in "Weight", with: @domain_name.weight
    click_on "Create Domain name"

    assert_text "Domain name was successfully created"
    click_on "Back"
  end

  test "should update Domain name" do
    visit domain_name_url(@domain_name)
    click_on "Edit this domain name", match: :first

    fill_in "Channel owner", with: @domain_name.channel_owner_id
    fill_in "Note", with: @domain_name.note
    fill_in "Note editor", with: @domain_name.note_editor
    fill_in "Site category", with: @domain_name.site_category_id
    fill_in "Weight", with: @domain_name.weight
    click_on "Update Domain name"

    assert_text "Domain name was successfully updated"
    click_on "Back"
  end

  test "should destroy Domain name" do
    visit domain_name_url(@domain_name)
    click_on "Destroy this domain name", match: :first

    assert_text "Domain name was successfully destroyed"
  end
end
