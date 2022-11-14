# coding: utf-8
require "application_system_test_case"

class ArtistsTest < ApplicationSystemTestCase
  setup do
    #@artist = artists(:one)
    @moderator = users(:user_moderator_general_ja)
    @css_swithcer_ja = 'div#language_switcher_top span.lang_switcher_ja'
    @css_swithcer_en = 'div#language_switcher_top span.lang_switcher_en'
end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

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
    zedd    = artists(:artist_zedd).title     # Best(Zedd)
    assert_equal "Zombies, The", zombies, "sanity check"
    assert_equal "Zedd",         zedd,    "sanity check2"

    # filtering and reverse-Sorting
    page.all('input[name="artists_grid[sex][]"]')[2].set(false)  # any sex
    fill_in "artists_grid_title_en", with: "Z"
    click_on "Apply"

    # ascending order
    page.find('table thead tr th.title_en div.order a.asc').click
    i_zombies = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text == zombies} # No <td> in <thead>, but all should have <td> in <tbody>
    i_zedd    = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text == zedd}
    assert_operator i_zedd, :<, i_zombies, "Should be normal-sorted, but... text="+page.all("table.artists_grid tbody tr").map{|m| m.all("td").map(&:text)}.inspect

    # descending order
    page.find('table thead tr th.title_en div.order a.desc').click
    i_zombies = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text == zombies} # No <td> in <thead>, but all should have <td> in <tbody>
    i_zedd    = page.all("table.artists_grid tbody tr").find_index{|nok| nok.all("td")[2].text == zedd}
    assert_operator i_zedd, :>, i_zombies, "Should be reverse-sorted, but... text="+page.all("table.artists_grid tbody tr").map{|m| m.all("td").map(&:text)}.inspect
  end
end

