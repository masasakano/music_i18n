# coding: utf-8
require "test_helper"

class Artists::Merges::ArtistWithIdsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:artist_saki_kubota)
    #@other = musics(:music_ihojin2)
    @editor = users(:user_editor_general_ja)  # (General) Editor can manage.
    @re_lennon = /Lennon/
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
    assert_match(@re_lennon, ary.sort[0], "Lennon should match but ary="+ary.inspect)
    assert_match(/ \[en\] /, ary.sort[0], "ary="+ary.sort.inspect)
    assert_match(/ \[ID=\d+\]/, ary.sort[0])
  #end

  #test "should get index even for new/edit paths" do
  #  sign_in @editor
    model = ChannelOwner.first
    %w(new edit edit/123).each do |path_fragment|
      get artists_merges_artist_with_ids_path(model,  params: {keyword: "nn", path: "/en/channel_owners/#{path_fragment}"}, format: :json)  # "/en/" should not exist??
      assert_response :success, "Failed for path=#{path_fragment.inspect}"
      ary = @response.parsed_body
      assert_match(@re_lennon, ary.sort[0], "(path=#{path_fragment}): Lennon should match but ary="+ary.inspect)
    end
  end

end
