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
  end

  test "should show artist" do
    get artist_url(@artist)
    assert_response :success
    #refute css_select('div.link-edit-destroy a')[0].text.include? "Edit"
  end

  test "should fail/succeed to get edit" do
    get edit_artist_url(@artist)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    get edit_artist_url(@artist)
    assert_response :success
    assert css_select('a').any?{|i| /\AShow\b/ =~ i.text.strip}  # More fine-tuning for CSS-selector is needed!
    css = css_select('div.link-edit-destroy a')
    assert(css.empty? || !css[0].text.include?("Edit"))
  end

  test "should fail/succeed to get new" do
    get new_artist_url(@artist)
    assert_response 401  # Somehow, not  :redirect
    #assert_redirected_to new_user_session_path

    sign_in @editor
    get new_artist_url
    css = css_select('p.navigate-link-below-form a')
    assert_equal 1, css.size
    assert_match(/\bindex$/i,   css.first.text)
    assert_match(%r@^(/en)?/artists(\?locale=en)?$@, css.first['href'])
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
      assert_redirected_to artist_url(artist)
    end

    assert_equal 'Test, The', artist.title
    assert_equal 'en', artist.orig_langcode
    assert artist.place.covered_by? Country['JPN']
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

