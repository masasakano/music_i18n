# coding: utf-8
require "test_helper"

class Musics::Merges::MusicWithIdsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @music = musics(:music_ihojin1)
    #@other = musics(:music_ihojin2)
    @editor = users(:user_editor_general_ja)  # (General) Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index if logged in as an editor" do
    get musics_merges_music_with_ids_path(@music,  params: {keyword: "ivepea", path: "/en/musics/#{@music.id}/merges/new"}, format: :json)
    assert_response 401

    sign_in @editor
    fpath = '/en/random'
    get musics_merges_music_with_ids_path(@music,  params: {keyword: "ivepea", path: fpath}, format: :json)
    assert_response :unprocessable_entity
    hs = @response.parsed_body
    assert_equal 'error', hs.keys[0]  # {"error":"Forbidden request to \"/en/random\""}

    get musics_merges_music_with_ids_path(@music,  params: {keyword: "ivepea", path: "/en/musics/#{@music.id}/merges/new"}, format: :json)
    assert_response :success
    ary = @response.parsed_body
    assert_equal Array, ary.class, 'ary='+ary.inspect
    assert_operator 0, :<, ary.size, # ["Give Peace a Chance Music2 [en] [ID=202458275]", "Give Peace a Chance Music3 [en] [ID=991327290]"]
    assert_match(/Give Peace/, ary[0])
    assert_match(/ \[en\] /, ary[0])
    assert_match(/ \[ID=\d+\]/, ary[0])
  end

end
