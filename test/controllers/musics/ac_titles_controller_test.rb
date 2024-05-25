# coding: utf-8
require "test_helper"

class Musics::AcTitlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @music = musics(:music_ihojin1)
    @artist = artists(:artist_saki_kubota)
    #@other = musics(:music_ihojin2)
    @editor = users(:user_editor_general_ja)  # (General) Editor can manage.
    @re_lennon = /Lennon/
  end

  teardown do
    Rails.cache.clear
  end

  test "should get index" do
    fpath = '/en/random'
    get musics_ac_titles_path( params: {keyword: "ivepea", path: fpath}, format: :json)
    assert_response :unprocessable_entity
    hs = @response.parsed_body
    assert_equal 'error', hs.keys[0]  # {"error":"Forbidden request to \"/en/random\""}

    get musics_ac_titles_path( params: {keyword: "ivepea", path: "/en/musics"}, format: :json)
    assert_response :success
    ary = @response.parsed_body
    assert_equal Array, ary.class, 'ary='+ary.inspect
    assert_operator 0, :<, ary.size  # ["Give Peace a Chance Music2", "Give Peace a Chance Music3"]
    assert_match(/^Give Peace [^\[]+$/, ary[0])

    get musics_ac_titles_url( params: {keyword: "異邦", path: "/en/harami_vids"}, format: :json)  # 2-character-long (minimum) Japanese word is auto-completed
    assert_response :success
    ary = @response.parsed_body
    assert_equal Array, ary.class, 'ary='+ary.inspect
    assert_operator 0, :<, ary.size, "ary.size=#{ary.size}" # ["異邦人", "異邦人や"]
    assert_match(/^異邦人/, ary.sort[0], "'異邦人' should match but ary="+ary.inspect)
  end
end
