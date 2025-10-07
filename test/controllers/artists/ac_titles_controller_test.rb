# coding: utf-8
require "test_helper"

class Artists::AcTitlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @artist = artists(:artist_ai)
    @artist2= artists(:artist_saki_kubota)
    #@editor = users(:user_editor_general_ja)  # (General) Editor can manage.
    @re_lennon = /Lennon/
  end

  teardown do
    Rails.cache.clear
  end

  test "should get index" do
    fpath = '/en/random'
    get artists_ac_titles_path( params: {keyword: "nno", path: fpath}, format: :json)
    assert_response :unprocessable_content
    hs = @response.parsed_body
    assert_equal 'error', hs.keys[0]  # {"error":"Forbidden request to \"/en/random\""}

    get artists_ac_titles_path( params: {keyword: "nno", path: "/en/artists"}, format: :json)
    assert_response :success
    ary = @response.parsed_body
    assert_equal Array, ary.class, 'ary='+ary.inspect
    assert_operator 0, :<, ary.size
    assert_match(/^John Lennon$/, ary[0])

    get artists_ac_titles_url( params: {keyword: "久保", path: "/ja/harami_vids"}, format: :json)  # 2-character-long (minimum) Japanese word is auto-completed
    assert_response :success
    ary = @response.parsed_body
    assert_equal Array, ary.class, 'ary='+ary.inspect
    assert_operator 0, :<, ary.size, "ary.size=#{ary.size}" # ["異邦人", "異邦人や"]
    assert_match(/^久保田/, ary.sort[0], "'久保田' should match but ary="+ary.inspect)
  end
end

