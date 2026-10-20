require "application_system_test_case"

class TranslationsTest < ApplicationSystemTestCase
  setup do
    @artist = artists(:artist_saki_kubota)
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

  test "updating a Translation and creating a sibling in a different language" do
    visit new_user_session_path  # already on this page.
    assert_text "Password"
    login_or_fail_index(@trans_moderator, succeed: true) # defined in test_system_helper.rb

    assert_selector "#language_switcher_top"
    page.find("#navbarColor02 li", text: "Translations").click

    ## Index page
    assert_selector "h1", text: "Translations"
    assert_selector 'input[value="Apply"]'
    assert_selector "table.datagrid-table"

    tra_ja = translations(:artist_saki_kubota_ja)
    assert_includes @artist.translations, tra_ja, "fixuture check"
    page.find("#translations_grid_title").fill_in(with: tra_ja.title)
    check "Artist"
    check "ID"  # extra column
    n_filtered_entries = Artist.select_regex(:titles, /#{Regexp.quote(tra_ja.title)}/).size
    # click_on "Apply"
    user_assert_grid_index_apply_to(n_filtered_entries: n_filtered_entries) # defined in test_system_helper.rb

    ## now, filtered Index page
    xpath_tr = xpath_grid_rows_contain(title: tra_ja.title)  # defined in test_helper.rb
    xpath_td = xpath_grid_rows_contain(id: nil, prefix: "")[1..-2]  # Only the last part of XPath
    xpath = xpath_tr + "/" + xpath_td
    assert_selector :xpath, xpath
    node_tds = page.find_all(:xpath, xpath)
    assert  node_tds.any?{ tra_ja.id.to_s == _1.text }, "pID row should match the Translation"

    node_tds.first.click  # pID should be clickable.
    assert_selector "h1", text: "A Translation for Artist"
    assert_selector "h1 .authorized_only", text: tra_ja.id.to_s  # Translation-pID should be in H1
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    ## now, Show page
    css = "div.item_langcode dd"
    assert_selector css
    assert_equal tra_ja.langcode, page.find(css).text.strip[0..1]

    css = "div.item_title dd"
    assert_selector css
    assert_equal tra_ja.title, page.find(css).text.strip

    css = "div.item_kind dd"
    assert_selector css
    assert_match(/^"?#{Regexp.quote tra_ja.kind}"?$/i, page.find(css).text.strip)

    TranslationsHelper::FLAG_TITLES.each_pair do |ek, etext|
      css = "div.item_#{ek.to_s} dd"
      assert_selector css
      assert_equal tra_ja.send(ek).inspect, page.find(css).text.strip
    end

    find("#sec_primary .edit_link a", text: "Edit").click
    assert_selector "h1", text: "Editing Translation"
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    ## now, Edit page

    assert_selector 'input#translation_translatable_type[value="Artist"]'  # Translatable should be un-editable
    assert_selector 'input#translation_translatable_type[readonly="readonly"]'
    assert_selector 'input#translation_translatable_id[readonly="readonly"]'

    assert_selector "textarea#translation_title", text: tra_ja.title
    new_title = tra_ja.title + "_new_test_title_1"
    new_memo = "New_Memo_1"
    new_weight = 0.12
    fill_in "Title",       with: new_title
    fill_in "Weight",      with: new_weight
    fill_in "Memo editor", with: new_memo
    %w(is_formal is_official is_true_name).each do |ecol|
      within("div.field_group_#{ecol}") do
        choose "Yes"
      end
    end

    click_on "Update Translation"
    assert_text "Translation was successfully updated"
    flash_regex_assert(/\bwas successfully updated\b/, type: [:notice, :success], system_test: true) # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb

    ## now, back to Translation-Show page

    assert_selector "h1", text: "A Translation for Artist"
    assert_selector "h1 .authorized_only", text: tra_ja.id.to_s  # Translation-pID should be in H1

    css = "div.item_title dd"
    assert_selector css
    assert_equal new_title, page.find(css).text.strip

    css = "div dd.item_weight"
    assert_selector css
    assert_equal new_weight, page.find(css).text.to_f

    css = "div dd.item_memo_editor"
    assert_selector css
    assert_equal new_memo, page.find(css).text.strip

    %w(is_formal is_official is_true_name).each do |ecol|
      css = "div.item_#{ecol} dd"
      assert_selector css
      assert_equal "true", page.find(css).text.strip
    end

    tra_ja.reload
    TranslationsHelper::FLAG_TITLES.each_pair do |ek, etext|
      css = "div.item_#{ek.to_s} dd"
      assert_selector css
      assert_equal tra_ja.send(ek).inspect, page.find(css).text.strip
    end

    assert_selector "#sec_primary_trans"
    assert_selector "table.all_registered_translations"

    css = "#sec_primary_trans div.add_other_language"
    assert_selector css
    within(css) do
      click_on "Add translation"
    end

    assert_selector "h1", text: "New Translation"
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    ## now, :new page

    assert_selector 'input#translation_translatable_type[value="Artist"]'  # Translatable should be un-editable
    assert_selector 'input#translation_translatable_type[readonly="readonly"]'
    assert_selector 'input#translation_translatable_id[readonly="readonly"]'

    assert_selector 'input#translation_kind_full[value="full"][checked="checked"]'  # on :create of the first Translation of +langcode+ for a parent, Default kind should be "full"

    es_title = "Spanish test title 1"
    within("div.field_group_is_true_name") do
      choose "No"
    end
    %w(is_literal is_internal).each do |ecol|
      within("div.field_group_#{ecol}") do
        choose "Yes"
      end
    end

    click_on "Create Translation"

    ## first try of :create should fail because neither :title nor :langcode has been specified.
    flash_regex_assert(/\berrors prohibited\b/, type: [:alert], system_test: true) # defined in test_helper.rb  (NOTE this is not a flash message but ActiveRecord#errors displayed.)
    flash_regex_assert(/\bLangcode can't be blank\b/i, type: [:alert], system_test: true)
    flash_regex_assert(/\b(blank\b.+\btitle|title\b.+\bblank)\b/i, type: [:alert], system_test: true)
    assert_selector "#form_main div.translation_langcode div.invalid-feedback", text: "can't be blank"

    assert_selector 'input#translation_is_true_name_false[checked="checked"]'  # input value should be preserved.
    assert_selector 'input#translation_is_literal_true[checked="checked"]'  # input value should be preserved.
    assert_selector 'input#translation_is_internal_true[checked="checked"]'  # input value should be preserved.

    assert_selector 'input#translation_is_formal_[checked="checked"]'  # Default value should remain.
    assert_selector 'input#translation_kind_full[value="full"][checked="checked"]'  # on :create of the first Translation of +langcode+ for a parent, Default kind should be "full"

    ## second try should succeed
    fill_in "Langcode",    with: "es"
    fill_in "Title",       with: es_title
    choose "Nickname"  # from "Kind"
    fill_in "Note",        with: new_memo

    click_on "Create Translation"

    assert_text "was successfully created"  # This may be "Artist was", opposed to "Translation was"...
    flash_regex_assert(/\bwas successfully created\b/, type: [:notice, :success], system_test: true) # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb

    ## back to parent Artist-Show page (NOT Translation-Show page, as intended!)

    assert_selector "h1", text: "Artist: "+@artist.best_translation.title
    css = "#sec_primary_trans table.all_registered_translations tbody tr.lang_banner.lang_banner_es"
    assert_selector css
    assert_selector css, text: "Spanish"  # because the current locale is English

    css = "#sec_primary_trans table.all_registered_translations tbody tr:last-child td.trans_action.trans_show a.show_link"
    assert_selector css
    find(css).click

    ## move to Translation-Show page

    assert_selector "h1", text: "A Translation for Artist"
    ensure_page_load_in_full_load  # defined in test_system_helper.rb
    # assert_selector "h1 .authorized_only", text: tra_ja.id.to_s  # Translation-pID should be in H1

    # pid = retrieve_pid_in_show  # defined in test_helper.rb  ## Does not work for Translation#show!
    tra_es = Translation.where(translatable_type: "Artist").order(created_at: :desc).first  # The "where" clause is required because :sync_child Translation of ChannelOwner's has been also created!
    /Translation.p?ID ?= ?(\d+)/ =~ find("h1").text
    assert_equal tra_es.id, $1.to_i, tra_es.inspect

    css = "div.item_langcode dd"
    assert_selector css
    assert_equal "es", (txt=page.find(css).text.strip)[0..1], txt

    css = "div dd.item_note"  ## CSS class is for <dd>, not for <div>
    assert_selector css
    assert_equal new_memo, (txt=page.find(css).text.strip), txt

    # Other input parameters should appear in :show page.
    [[:title, es_title], [:kind, '"nickname"'],
     [:is_true_name, "false"], [:is_literal, "true"], [:is_internal, "true"]].each do |ea|
      css = "div.item_#{ea[0]} dd"
      assert_selector css
      assert_equal ea[1], page.find(css).text.strip, ea.inspect+" does not match..."
    end

    css = "div dd.item_weight"
    assert_selector css
    # def_weight = Translation.new(translatable: @artist, langcode: "ru", is_orig: false).def_weight(@trans_moderator)
    assert_equal Translation::MAX_WEIGHT_VISIBLE.quo(10)*11, page.find(css).text.to_f  # because of [:is_internal, "true"]; see also Translation.get_reference_increment about the 10% increment

    TranslationsHelper::FLAG_TITLES.each_pair do |ek, etext|
      css = "div.item_#{ek.to_s} dd"
      assert_selector css
      assert_equal tra_es.send(ek).inspect, page.find(css).text.strip
    end

    click_on "Back", match: :first
  end

  #test "destroying a Translation" do
  #  visit translations_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Translation was successfully destroyed"
  #end
end
