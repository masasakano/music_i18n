# coding: utf-8
require 'test_helper'

class ArtistsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:artist1)
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get artists_url
    assert_response :success
    #assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden
    assert_nil current_user_display_name(is_system_test: false)  # defined in test_helper.rb

    art = artists(:artist_proclaimers)
    assert       art.translations.where(langcode: "en").exists?, "sanity check"
    refute       art.translations.where(langcode: "ja").exists?, "sanity check"
    assert_equal "en", art.orig_langcode, "sanity check"
    tra = art.best_translation
    alt_tit = "alt-proclaimers"
    tra.update!(alt_title: alt_tit)
    art.translations.reset

    get artists_url, params: {artists_grid: {title_ja: alt_tit}}  # search by English alt-title
    css_txt = 'table.datagrid tbody tr'
    assert  css_select(css_txt+" td")[0].text.blank?  # ja-title
    assert  css_select(css_txt+" td")[1].text.blank?  # ja-alt_title
    assert_equal 1, css_select(css_txt).size
    assert  (tit=css_select(css_txt+" td")[2].text).present?  # en-title/alt_title
    assert_match(%r@\s+\[#{Regexp.quote(alt_tit)}\]\z@, tit.strip)

    if is_env_set_positive?('TEST_STRICT')  # defined in application_helper.rb
      w3c_validate "Artist index"  # defined in test_helper.rb (see for debugging help)
    end  # only if TEST_STRICT, because of invalid HTML for datagrid filter for Range
  end

  test "should show artist" do
    get artist_url(@artist)
    assert_response :success
    w3c_validate "Artist show"  # defined in test_helper.rb (see for debugging help)
    #refute css_select('div.link-edit-destroy a')[0].text.include? "Edit"

    artist_psy = artists(:artist_psy)
    get artist_url(artist_psy)
    assert_response :success
    css_str = 'table.all_registered_translations tr.lang_banner_ko'
    css = css_select(css_str)
    assert_equal 1, css.size
    assert_includes css_select(css_str+" th")[0].text, "한국어"

    sign_in @editor

    # tests of display of wiki
    wiki_en_root = "en.wikipedia.org/wiki/Ben_E._King"
    hs = {
      "wiki_en"=>"https://"+wiki_en_root,
      "wiki_ja"=>"%E3%83%99%E3%83%B3%E3%83%BBE%E3%83%BB%E3%82%AD%E3%83%B3%E3%82%B0",
      }
    patch artist_url @artist, params: { artist: hs }
    assert_response :redirect
    assert_redirected_to artist_url @artist

    follow_redirect!
    assert_equal(@editor.display_name, current_user_display_name(is_system_test: false))  # defined in test_helper.rb
    assert_equal 1, css_select('dt#show_wikipedia_ja').size
    #puts "DEBUG: HTML:\n"+css_select('dt#show_wikipedia').to_html
    css = css_select('dd#show_wikipedia_dd_ja a')
    assert_equal "https://ja.wikipedia.org/wiki/"+hs["wiki_ja"], css[0]["href"]
    assert_equal "ja.wikipedia.org/wiki/ベン・E・キング",        css[0].text
    css = css_select('dd#show_wikipedia_dd_en a')
    assert_equal "https://en.wikipedia.org/wiki/Ben_E._King", CGI.unescape(css[0]["href"])
    assert_equal wiki_en_root, css[0].text
  end

  test "should fail/succeed to get new" do
    get new_artist_url(@artist)
    assert_response 401  # Somehow, not  :redirect
    #assert_redirected_to new_user_session_path

    sign_in @editor
    get new_artist_url
    assert_response :success

    #puts css_select('body')[0].to_html
    #puts response.body
    w3c_validate "Artist new"  # defined in test_helper.rb (see for debugging help)

    css = css_select('p.navigate-link-below-form a')
    assert_equal 1, css.size
    assert_match(/\bindex$/i,   css.first.text)
    assert_match(%r@^(/en)?/artists(\?locale=en)?$@, css.first['href'])
    assert_empty css_select(css_query(:trans_new, :is_orig_radio, model: Artist)), "is_orig selection should not be provided, but..."  # defined in helpers/test_system_helper
  end

  test "should create" do
    sign_in @editor

    # Creation success
    artist = nil
    assert_difference('Artist.count', 1) do
      hs = {
        "langcode"=>"en",
        "title"=>"The Tｅst",
        "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
        "place.prefecture_id.country_id"=>Country['JPN'].id.to_s,
        "place.prefecture_id"=>"", "place_id"=>"",
        "sex_id"=>Sex.unknown.id.to_s,
        "birth_year"=>"", "birth_month"=>"", "birth_day"=>"", "wiki_en"=>"", "wiki_ja"=>"",
        #"music"=>"", "engage_how"=>[""],
        "note"=>""}
      post artists_url, params: { artist: hs }
      assert_response :redirect
      artist = Artist.last
      assert_equal "Test, The", artist.title, "Artist: "+artist.inspect
      assert_redirected_to artist_url(artist)
    end

    assert_equal 'Test, The', artist.title
    assert_equal 'en', artist.orig_langcode
    assert artist.place.covered_by? Country['JPN']
  end

  test "should fail/succeed to get edit" do
    get edit_artist_url(@artist)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    # get edit_artist_url(@artist) # This will result in W3C error as the wikipedia page is not a valid URL (without a https://)
    get edit_artist_url(artists(:artist_saki_kubota))
    assert_response :success
    w3c_validate "Artist edit"  # defined in test_helper.rb (see for debugging help)
    assert css_select('a').any?{|i| /\AShow\b/ =~ i.text.strip}  # More fine-tuning for CSS-selector is needed!
    css = css_select('div.link-edit-destroy a')
    assert(css.empty? || !css[0].text.include?("Edit"))
  end

  test "should update" do
    sign_in @editor

    artist_orig = @artist.dup

    # Update success
    hs_tmpl = {
      "place.prefecture_id.country_id"=>Country['AUS'].id.to_s,
      "place.prefecture_id"=>"", "place_id"=>"",
      "sex_id"=>Sex.unknown.id.to_s,
      "birth_year"=>"", "birth_month"=>"", "birth_day"=>"", "wiki_en"=>"", "wiki_ja"=>"",
      "note"=>""}
    hs = {}.merge hs_tmpl
    patch artist_url @artist, params: { artist: hs }
    assert_response :redirect
    assert_redirected_to artist_url @artist

    @artist.reload
    assert @artist.place.covered_by? Country['AUS']
    assert_not_equal artist_orig.place, @artist.place

    # Update success with a significant place
    place_perth = places( :perth_aus )
    unknown_prefecture_aus = prefectures( :unknown_prefecture_aus )
    hs = hs_tmpl.merge({
       'place.prefecture_id' => unknown_prefecture_aus.id,
       'place_id' => place_perth.id,
       'birth_year' => 1950
    })
    patch artist_url @artist, params: { artist: hs }
    assert_response :redirect
    assert_redirected_to artist_url @artist

    @artist.reload
    assert_equal place_perth, @artist.place
    assert_equal 1950,        @artist.birth_year
  end

  test "should destroy artist if privileged" do
    artist3 = artists(:artist3)

    # Fail: No privilege
    assert_difference('Artist.count', 0) do
      delete artist_url(artist3)
      assert_response :redirect
      assert_redirected_to new_user_session_path
    end

    sign_in @editor

    # Success: Successful deletion
    assert_difference('Artist.count', -1) do
      assert_difference('Translation.count', -2) do  # artist3 (ハラミちゃん) has 2 translations.
        assert_difference('HaramiVidMusicAssoc.count', 0) do
          assert_difference('Engage.count', -1) do
            assert_difference('Music.count', 0) do
              assert_difference('Place.count', 0) do
                delete artist_url(artist3)
              end
            end
          end
        end
      end
    end

    assert_response :redirect
    assert_redirected_to artists_url
    assert_raises(ActiveRecord::RecordNotFound){ artist3.reload }
  end
end

