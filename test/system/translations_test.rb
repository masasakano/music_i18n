require "application_system_test_case"

class TranslationsTest < ApplicationSystemTestCase
  setup do
    @translation = translations(:one)
  end

  test "visiting the index" do
    visit translations_url
    assert_selector "h1", text: "Translations"
  end

  test "creating a Translation" do
    visit translations_url
    click_on "New Translation"

    fill_in "Alt romaji", with: @translation.alt_romaji
    fill_in "Alt ruby", with: @translation.alt_ruby
    fill_in "Alt title", with: @translation.alt_title
    fill_in "Create user", with: @translation.create_user_id
    check "Is orig" if @translation.is_orig
    fill_in "Langcode", with: @translation.langcode
    fill_in "Note", with: @translation.note
    fill_in "Romaji", with: @translation.romaji
    fill_in "Ruby", with: @translation.ruby
    fill_in "Title", with: @translation.title
    fill_in "Translatable", with: @translation.translatable_id
    fill_in "Translatable type", with: @translation.translatable_type
    fill_in "Update user", with: @translation.update_user_id
    fill_in "Weight", with: @translation.weight
    click_on "Create Translation"

    assert_text "Translation was successfully created"
    click_on "Back"
  end

  test "updating a Translation" do
    visit translations_url
    click_on "Edit", match: :first

    fill_in "Alt romaji", with: @translation.alt_romaji
    fill_in "Alt ruby", with: @translation.alt_ruby
    fill_in "Alt title", with: @translation.alt_title
    fill_in "Create user", with: @translation.create_user_id
    check "Is orig" if @translation.is_orig
    fill_in "Langcode", with: @translation.langcode
    fill_in "Note", with: @translation.note
    fill_in "Romaji", with: @translation.romaji
    fill_in "Ruby", with: @translation.ruby
    fill_in "Title", with: @translation.title
    fill_in "Translatable", with: @translation.translatable_id
    fill_in "Translatable type", with: @translation.translatable_type
    fill_in "Update user", with: @translation.update_user_id
    fill_in "Weight", with: @translation.weight
    click_on "Update Translation"

    assert_text "Translation was successfully updated"
    click_on "Back"
  end

  test "destroying a Translation" do
    visit translations_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Translation was successfully destroyed"
  end
end
