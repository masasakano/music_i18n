require "application_system_test_case"

class TranslationsTest < ApplicationSystemTestCase
  setup do
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Translations"
  #  @translation = translations(:one)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting the index" do
    assert_index_fail_succeed(translations_path, @h1_title, user_fail: @editor_ja, user_succeed: @translator)  # defined in test_system_helper.rb
    def_artist = Artist.default(:HaramiVid)
    def_artist_tit_ja = def_artist.title(langcode: :ja)
    def_artist_tit_en = def_artist.title(langcode: :en)

    n_all_entries = Translation.count
    n_tras    = Translation.select_regex(:all, def_artist_tit_ja, sql_regexp: true, where: {translatable_type: "Artist"}).count
    n_tras_en = Translation.select_regex(:all, def_artist_tit_en, sql_regexp: true, where: {translatable_type: "Artist"}).count
    check "Artist"
    check "Sex"
    page.find("#translations_grid_title").fill_in(with: def_artist_tit_ja)
    user_assert_grid_index_apply_to(n_filtered_entries: n_tras, n_all_entries: n_all_entries, langcode: :en)
    assert_equal n_tras, page.all(CSSGRIDS[:tb_tr]).size

    tra2 = Translation.new(title: def_artist_tit_ja, langcode: "ja", is_orig: true, weight: 2000, note: "sex-def-title2")
    sex1 = Sex.first
    assert_difference('sex1.translations.count'){
      sex1.translations << tra2 }

    page.find("#translations_grid_title").fill_in(with: def_artist_tit_ja)
    user_assert_grid_index_apply_to(n_filtered_entries: n_tras+1, n_all_entries: n_all_entries+1)  # click_on "Apply" and wait for loading; defined in test_system_helper.rb
    assert_equal n_tras+1, page.all(CSSGRIDS[:tb_tr]).size

    page.find("#translations_grid_title").fill_in(with: "^"+def_artist_tit_ja+"$")
    user_assert_grid_index_apply_to(n_filtered_entries: n_tras+1, n_all_entries: n_all_entries+1)  # click_on "Apply" and wait for loading; defined in test_system_helper.rb
    assert_equal n_tras+1, page.all(CSSGRIDS[:tb_tr]).size

    assert_equal "ハラミ", def_artist.best_translation("ja").alt_title, "fixture test"
    page.find("#translations_grid_title").fill_in(with: "^ハラミ$")
    user_assert_grid_index_apply_to(n_filtered_entries: 1, n_all_entries: n_all_entries+1)  # click_on "Apply" and wait for loading; defined in test_system_helper.rb
    assert_equal 1, page.all(CSSGRIDS[:tb_tr]).size

    page.find("#translations_grid_title").fill_in(with: '^#{exit}ハラミ#{exit}$')  # Input should be sanitized.
    user_assert_grid_index_apply_to(n_filtered_entries: 0, n_all_entries: n_all_entries+1, start_entry: 0)  # click_on "Apply" and wait for loading; defined in test_system_helper.rb
    # assert_equal 0, page.all(CSSGRIDS[:tb_tr]).size  # An empty row with "---" is displayed when the table has no rows.
  end

  #test "creating a Translation" do
  #  visit translations_url
  #  click_on "New Translation"

  #  fill_in "Alt romaji", with: @translation.alt_romaji
  #  fill_in "Alt ruby", with: @translation.alt_ruby
  #  fill_in "Alt title", with: @translation.alt_title
  #  fill_in "Create user", with: @translation.create_user_id
  #  check "Is orig" if @translation.is_orig
  #  fill_in "Langcode", with: @translation.langcode
  #  fill_in "Note", with: @translation.note
  #  fill_in "Romaji", with: @translation.romaji
  #  fill_in "Ruby", with: @translation.ruby
  #  fill_in "Title", with: @translation.title
  #  fill_in "Translatable", with: @translation.translatable_id
  #  fill_in "Translatable type", with: @translation.translatable_type
  #  fill_in "Update user", with: @translation.update_user_id
  #  fill_in "Weight", with: @translation.weight
  #  click_on "Create Translation"

  #  assert_text "Translation was successfully created"
  #  click_on "Back"
  #end

  #test "updating a Translation" do
  #  visit translations_url
  #  click_on "Edit", match: :first

  #  fill_in "Alt romaji", with: @translation.alt_romaji
  #  fill_in "Alt ruby", with: @translation.alt_ruby
  #  fill_in "Alt title", with: @translation.alt_title
  #  fill_in "Create user", with: @translation.create_user_id
  #  check "Is orig" if @translation.is_orig
  #  fill_in "Langcode", with: @translation.langcode
  #  fill_in "Note", with: @translation.note
  #  fill_in "Romaji", with: @translation.romaji
  #  fill_in "Ruby", with: @translation.ruby
  #  fill_in "Title", with: @translation.title
  #  fill_in "Translatable", with: @translation.translatable_id
  #  fill_in "Translatable type", with: @translation.translatable_type
  #  fill_in "Update user", with: @translation.update_user_id
  #  fill_in "Weight", with: @translation.weight
  #  click_on "Update Translation"

  #  assert_text "Translation was successfully updated"
  #  click_on "Back"
  #end

  #test "destroying a Translation" do
  #  visit translations_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Translation was successfully destroyed"
  #end
end
