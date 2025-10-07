require "test_helper"

class EngageMultiHowsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @engage = engages(:engage1)
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    sign_in @editor
    artist = Artist.first
    music  = Music.first
    get engage_multi_hows_url(artist_id: artist.id, music_id: music.id)
    assert_response :success
  end

  test "should create" do
    sign_in @editor

    # Creation success
    assert_difference('Engage.count', 2) do
      post engage_multi_hows_url, params: { engage: { artist_id: @engage.artist.id, music_id: @engage.music.id, engage_how: [engage_hows(:engage_how_composer).id, engage_hows(:engage_how_player).id], year: 1234 } }
      assert_response :redirect
      _assert_response_url(@response, @engage)
    end
  end

  test "should get show" do
    sign_in @editor
    get engage_multi_how_url(@engage.id)
    assert_response :redirect
    _assert_response_url(@response, @engage)
  end

  test "should get edit" do
    sign_in @editor
    get edit_engage_multi_how_url(@engage.id)
    assert_response :redirect
    _assert_response_url(@response, @engage)
  end

  test "should create/replace/delete" do
    sign_in @editor

    artist_ai = artists( :artist_ai )
    artist_proclaimers = artists( :artist_proclaimers )
    music_story = musics( :music_story )
    engage_ai_story = engages( :engage_ai_story )
    engage_how_composer = engage_hows( :engage_how_composer )
    engage_how_player = engage_hows( :engage_how_player )

    # sanity check (consistency check of the fixtures)
    assert_equal 1, engage_ai_story.harami1129s.count
    assert_equal artist_ai,   engage_ai_story.artist
    assert_equal music_story, engage_ai_story.music

    engages = {}  # Engages for AI's Story
    harami1129 = engage_ai_story.harami1129s.first
    engages[:original] = harami1129.engage

    # Deletion failure due to a dependent Harami1129
    assert_difference('Engage.count', 0) do
      post engage_multi_hows_url, params: { engage: { artist_id: artist_ai.id, music_id: music_story.id, engage_how: [""], year: "" }.merge(_get_hs_destroy_hash(engages[:original])) }
      assert_response :unprocessable_content
      harami1129.reload
      assert_equal engages[:original], harami1129.engage
    end

    ## creation success
    assert_difference('Engage.count', 2) do
      hows = ["", engage_how_composer.id, engage_how_player.id]
      post engage_multi_hows_url, params: { engage: { artist_id: artist_ai.id, music_id: music_story.id, engage_how: hows, year: ""} }
      assert_response :redirect
      _assert_response_url(@response, engage_ai_story)
    end

    ## sets Engage Hash for later use.
    assert_equal 3, Engage.where(artist_id: artist_ai.id, music_id: music_story.id).count
    Engage.where(artist_id: artist_ai.id, music_id: music_story.id).each do |ee|
      next if ee == engages[:original] # => with EngageHow.unknown
      case ee.engage_how
      when engage_how_composer
        engages[:composer] = ee
      when engage_how_player
        engages[:player] = ee
      else
        raise 'Should not happen.'
      end
    end
    harami1129.reload
    assert_equal engages[:original], harami1129.engage

    ## deletion 2 Engage-s success
    assert_difference('Engage.count', -2) do
      post engage_multi_hows_url, params: { engage: { artist_id: artist_ai.id, music_id: music_story.id, engage_how: [""], year: ""}.merge(_get_hs_destroy_hash(engages[:original], engages[:composer])) }
      assert_response :redirect
      _assert_response_url(@response, engage_ai_story)

      harami1129.reload
      assert_equal engages[:player], harami1129.engage

      assert     Engage.exists? engages[:player].id
      assert_not Engage.exists? engages[:original].id
      assert_not Engage.exists? engages[:composer].id
    end

    ## deletion of the last Engage success if there is another one with another Artist
    engages[:composer_proc] = Engage.create!(music: music_story, artist: artist_proclaimers, engage_how: engage_how_composer)
    engages[:player_proc]   = Engage.create!(music: music_story, artist: artist_proclaimers, engage_how: engage_how_player)
    assert_operator engages[:player_proc].engage_how, '>', engages[:composer_proc].engage_how # sanity check of Fixtures
    assert_difference('Engage.count', -1) do
      post engage_multi_hows_url, params: { engage: { artist_id: artist_ai.id, music_id: music_story.id, engage_how: [""], year: ""}.merge(_get_hs_destroy_hash(engages[:player])) }
      assert_response :redirect
      _assert_response_url(@response, engage_ai_story)

      harami1129.reload
      assert_equal engages[:composer_proc], harami1129.engage # changed to a different Artist
      assert_not Engage.exists? engages[:player].id
    end

    ## Creation and deletion at the same time (basically replacing)
    ## Posting to EngageMultiHows of Proclaimer/Story page.
    eh_unknown = EngageHow.unknown
    assert_difference('Engage.count', -1) do
      post engage_multi_hows_url, params: { engage: { artist_id: artist_proclaimers.id, music_id: music_story.id, engage_how: ["", eh_unknown.id], year: ""}.merge(_get_hs_destroy_hash(engages[:composer_proc], engages[:player_proc])) }
      assert_response :redirect
      _assert_response_url(@response, Engage.new(artist_id: artist_proclaimers.id, music_id: music_story.id))  # Engage.new is used just to pass 2 parameters

      harami1129.reload
      assert_equal artist_proclaimers,  harami1129.engage.artist # changed to a different Artist
      assert_equal eh_unknown,          harami1129.engage.engage_how
      assert_not Engage.exists? engages[:composer_proc].id
      assert_not Engage.exists? engages[:player_proc].id
    end
  end

  # Utility to get "to_destroy_20" etc
  # @param *engages [Array<Engage>]
  def _get_hs_destroy_hash(*engages)
    [engages].flatten.map{|eng|
      [sprintf("to_destroy_%d", eng.id), "true"]
    }.to_h
  end

  # Test URI path and query parameters, excluding a locale.
  def _assert_response_url(response, engage)
    ### Instead of
    # url = sprintf "%s?artist_id=%d&music_id=%d", engage_multi_hows_url, @engage.artist.id, @engage.music.id
    # assert_redirected_to url
    #
    uri = Addressable::URI.parse(response.location)
    assert_equal Addressable::URI.parse(engage_multi_hows_url).path, uri.path
    hs = {"artist_id" => engage.artist.id.to_s, "music_id" => engage.music.id.to_s}
    assert_equal hs, uri.query_values.slice(*(%w(artist_id music_id))) # ignoring locale
  end
end
