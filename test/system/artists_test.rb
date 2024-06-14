# coding: utf-8
require "application_system_test_case"

class ArtistsTest < ApplicationSystemTestCase
  setup do
    @artist = artists(:artist_ai)
    @moderator = users(:user_moderator_general_ja)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @css_swithcer_ja = 'div#language_switcher_top span.lang_switcher_ja'
    @css_swithcer_en = 'div#language_switcher_top span.lang_switcher_en'
    @h1_title = "Artists"
    @button_text = {
      create: "Create Artist",
      update: "Update Artist",
    }
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  def _get_stats
    stats_str = page.find('.pagenation_stats').text
    mat = %r@(?:Page |第)\s*(\d+)\s*頁? \((\d+)[^\d]+(\d+)\)\s*/\s*(\d+) [^G]+(Grand total|全登録数)[^\d]+(\d+)@.match(stats_str)
    stats = {
      i_page: mat[1].to_i,
      i_from: mat[2].to_i,
      i_to: mat[3].to_i,
      n_cur:       mat[4].to_i,
      word_tot: mat[5],
      n_grand_tot: mat[6].to_i,
    }
  end

  test "visiting the index" do
    # Artist#index (EN)
    visit artists_url
    assert_selector "h1", text: "Artists"
    assert_no_selector 'form.button_to'  # No button if not logged-in.

    assert_equal "Sex",        page.find('table thead tr th.sex').text.strip
    assert_equal "Title [Alt] (En)", page.find('table thead tr th.title_en').text.split(/\n/)[0].strip  # text followed by "\n ↑ ↓"
    stats_str = page.find('.pagenation_stats').text
    assert stats_str.include?("Grand total")

    stats1 = _get_stats

    assert_equal 1, stats1[:i_page]
    assert_equal 1, stats1[:i_from], "stats1 = "+stats1.inspect
    assert_operator 25, :>=, stats1[:i_to]  # max 25 entries per page

    ## language switcher
    assert_equal "English", page.find(@css_swithcer_en).text
    refute_selector                   @css_swithcer_en+" a"
    assert_equal "日本語",  page.find(@css_swithcer_ja).text
    assert_equal "日本語",  page.find(@css_swithcer_ja+" a").text
    page.find(@css_swithcer_ja+" a").click

    ## transited to Japanese
    refute_selector                   @css_swithcer_ja+" a"
    assert_equal "English", page.find(@css_swithcer_en).text
    assert_equal "English", page.find(@css_swithcer_en+" a").text

    assert page.find('div#navbar_upper_any').text.include?("動画")
    assert_equal "性別",     page.find('table thead tr th.sex').text.strip
    assert_equal "英語名称 [別称]", page.find('table thead tr th.title_en').text.split(/\n/)[0].strip  # text followed by "\n ↑ ↓"

    ## English sorting (the total number should not change)
    page.find('table thead tr th.title_en div.order a.desc').click
    stats2 = _get_stats
    assert_equal "全登録数", stats2[:word_tot]

    assert_equal stats1[:i_page],      stats2[:i_page] 
    assert_equal stats1[:i_from],      stats2[:i_from] 
    assert_equal stats1[:i_to],        stats2[:i_to] 
    assert_equal stats1[:n_cur],       stats2[:n_cur] 
    assert_equal stats1[:n_grand_tot], stats2[:n_grand_tot] 

    ## transited to English
    page.find(@css_swithcer_en+" a").click
    assert_equal "English", page.find(@css_swithcer_en).text
    refute_selector                   @css_swithcer_en+" a"
    assert_equal "日本語",  page.find(@css_swithcer_ja+" a").text

    # Filtering
    page.all('input[name="artists_grid[sex][]"]')[2].set(true)  # "input#artists_grid_sex_not\ known" should work?
    #find_field("Sex").choose('not known')  # invalid b/c "for" are inconsistent.
    click_on "Apply"

    stats3 = _get_stats
    assert_equal "Grand total", stats3[:word_tot]

    assert_equal stats1[:i_page],      stats3[:i_page] 
    assert_equal stats1[:i_from],      stats3[:i_from] 
    #assert_equal stats1[:i_to],        stats3[:i_to] 
    assert_operator stats1[:n_cur], :>, stats3[:n_cur]  # Number decreased after filtering.
    assert_equal stats1[:n_grand_tot], stats3[:n_grand_tot]  # Total number for the model remains the same

    # sanity checks of fixtures
    zombies = artists(:artist_zombies).title  # Best(Zombies, The). Other-inferior-Trans(TheZombies); n.b., because of the latter this may come before Zedd!
    zedd    = (art_zedd=artists(:artist_zedd)).title     # Best(Zedd)
    assert_equal "Zombies, The", zombies, "sanity check"
    assert_equal "Zedd",         zedd,    "sanity check2"

    # filtering and reverse-Sorting
    page.all('input[name="artists_grid[sex][]"]')[2].set(false)  # any sex
    fill_in "artists_grid_title_en", with: "Z"
    click_on "Apply"

    # ascending order
    page.find('table thead tr th.title_en div.order a.asc').click
    i_zombies = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text[0, zombies.size] == zombies} # No <td> in <thead>, but all should have <td> in <tbody>
    i_zedd    = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text == zedd}  # For Editors: zedd+"*"

      assert_nil current_user_display_name(is_system_test: true)  # defined in test_helper.rb
    # This sometimes happens... Basically, "Zedd*" is displayed as opposed to "Zedd".
    # "Zedd*" should be displayed only for Editors.  However, despite this is viewed
    # by an unauthenticated user, "Zedd*" is displayed here.  Why?
    if !i_zedd
      assert_nil current_user_display_name(is_system_test: true)  # defined in test_helper.rb
      print "DEBUG-i_zedd(#{File.basename __FILE__}): @qualified_as=#{BaseGrid.instance_variable_get(:@qualified_as).inspect}\n"
    end

    assert_equal    "en", art_zedd.orig_langcode
    assert_operator i_zedd, :<, i_zombies, "Should be normal-sorted, but... text="+page.all("table.artists_grid tbody tr").map{|m| m.all("td").map(&:text)}.inspect

    # descending order
    page.find('table thead tr th.title_en div.order a.desc').click
    i_zombies = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text[0, zombies.size] == zombies} # No <td> in <thead>, but all should have <td> in <tbody>
    i_zedd    = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text == zedd}
    assert_operator i_zedd, :>, i_zombies, "Should be reverse-sorted, but... text="+page.all("table.artists_grid tbody tr").map{|m| m.all("td").map(&:text)}.inspect

    ## transits to Japanese
    assert_equal "日本語",  page.find(@css_swithcer_ja).text
    assert_equal "日本語",  page.find(@css_swithcer_ja+" a").text
    page.find(@css_swithcer_ja+" a").click
    refute_selector                   @css_swithcer_ja+" a"
    assert_equal "English", page.find(@css_swithcer_en).text

    ## Test of sorting. In the initial state, Haramichan should come first. 
    #  In any subsequent sorting, the initial condition should be ignored.
    title_newest_ja = "最新"
    title_newest_en = "A"  # should come first in English-title sorting
    tnow = Time.now
    artist_newest = Artist.create_with_orig_translation!({sex: Sex.first, created_at: tnow}, translation: {title: title_newest_ja, langcode: 'ja'})
    artist_newest.create_translation!(title: title_newest_en, is_orig: false, langcode: 'en')
    artist_newest.reload
    Artist.create_with_orig_translation!({sex: Sex.first, created_at: Time.at(1)}, translation: {title: "B", langcode: 'en'})  # This one (newest ID, old created_at) is created in order to properly test "created_id DESC" condition in ArtistsController#index; otherwise there is a chance artist_newest would come first right after Haramichan anyway simply because of its ID (to be fair, usually youngest ID comes first and so this artist would not do much in fact, as I realised later).
    assert_equal tnow, artist_newest.created_at, "sanity check fails: "+artist_newest.inspect
    assert_equal artist_newest, Artist.order(created_at: :desc).first, "sanity check fails [first, last]: "+[Artist.order(created_at: :desc).first, Artist.order(created_at: :desc).last].inspect

    ## Reset
    page.find("form#new_artists_grid div.datagrid-actions a.datagrid-reset").click
    assert_empty page.find("form#new_artists_grid div.datagrid-filter input#artists_grid_title_en").text, 'sanity check'

    assert_equal "ハラミちゃん",  page.all("table.artists_grid tbody tr td.title_ja")[0].text.strip
    assert_equal title_newest_ja, page.all("table.artists_grid tbody tr td.title_ja")[1].text.strip

    page.find('table thead tr th.title_en div.order a.asc').click
    first_non_null_en_text = page.all("table.artists_grid tbody tr td.title_en").find{|i| !i.text.strip.empty?}.text.strip
    assert_equal title_newest_en, first_non_null_en_text

    page.find('table thead tr th.title_en div.order a.desc').click  # entry with NULL may come first, but at least this operation should succeed
    first_non_null_en_text = page.all("table.artists_grid tbody tr td.title_en").find{|i| !i.text.strip.empty?}.text.strip
    refute_equal title_newest_en, first_non_null_en_text

    assert_no_selector "input#artists_grid_id"
  end

  test "should create/update artist" do
    new_model_title = "New Artist"
    visit new_artist_url  # direct jump -> fail
    refute_text new_model_title
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_gen.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_equal(@moderator_gen.display_name, current_user_display_name(is_system_test: true))  # defined in test_helper.rb

    visit artists_url
    assert_selector "input#artists_grid_id"

    n_records_be4 = page.all("div#artists table tr").size - 1
    click_on "New Artist"

    assert_selector "h1", text: new_model_title
    assert_no_selector css_query(:trans_new, :is_orig_radio, model: Prefecture)  # "is_orig selection should not be provided, but..."  # css_query defined in helpers/test_system_helper
    page_find_sys(:trans_new, :langcode_radio, model: Artist).choose('English')  # defined in helpers/test_system_helper

    page.find('input#artist_title').fill_in with: @artist.title  # This is a duplicate.

    choose("female")
    fill_in "Birth year", with: 1998

    click_on @button_text[:create]

    # assert_match(/ prohibited /, page_find_sys(:error_div, :title).text)  # Artist with the same name is OK unless other information is identical.

    assert_text "successfully created."

    assert_selector "h1", text: "Artist: "+@artist.title

    page.find("a.link-edit").click
    assert_selector "h1", text: "Editing Artist: "+@artist.title

    assert_equal Sex["female"].id, page.find_field(name: "artist[sex_id]", checked: true)["value"].to_i
    assert_equal "1998", page.find_field(name: 'artist[birth_year]').value

    assert_no_selector('input#artist_title')

    page.find_field(name: 'artist[birth_day]').fill_in with: 31
    click_on @button_text[:update]

    assert_text "successfully updated."

    assert_match(/(\b1998\b.+\b31\b|\b31\b.+\b1998\b)/, page.find_all(:xpath, "//section[@id='sec_primary_show']//dt[@title='Birthday']/following-sibling::dd")[0].text)

  end
end

