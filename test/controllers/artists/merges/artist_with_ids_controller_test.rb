# coding: utf-8
require "test_helper"

class Artists::Merges::ArtistWithIdsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:artist_saki_kubota)
    #@other = musics(:music_ihojin2)
    @editor = users(:user_editor_general_ja)  # (General) Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index if logged in as an editor" do
    get artists_merges_artist_with_ids_path(@artist,  params: {keyword: "iho", path: "/en/artists/#{@artist.id}/merges/new"}, format: :json)
    assert_response 401

    sign_in @editor
    fpath = '/en/random'
    get artists_merges_artist_with_ids_path(@artist,  params: {keyword: "iho", path: fpath}, format: :json)
    assert_response :unprocessable_entity
    hs = @response.parsed_body
    assert_equal 'error', hs.keys[0]  # {"error":"Forbidden request to \"/en/random\""}

    get artists_merges_artist_with_ids_path(@artist,  params: {keyword: "nn", path: "/en/artists/#{@artist.id}/merges/new"}, format: :json)
    assert_response :success
    ary = @response.parsed_body
    assert_equal Array, ary.class, 'ary='+ary.inspect
    assert_operator 0, :<, ary.size, # ["Madonna [en] [ID=202458275]", "John Lennon [en] [ID=991327290]"]
    assert_match(/Lennon/, ary.sort[0], "Lennon should match but ary="+ary.inspect)
    assert_match(/ \[en\] /, ary[0])
    assert_match(/ \[ID=\d+\]/, ary[0])
  end

end
