# coding: utf-8
require "test_helper"

class ArtistMusicPlays::EditMultisControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event = events(:three)
    @evit  = EventItem.new_default(:HaramiVid, place: places(:tocho), event: @event, save_event: true)
    @music1 = musics(:music1)
    @music2 = musics(:music2)
    @harami  = artists(:artist_harami)
    @artist3 = artists(:artist3)
    @artist4 = artists(:artist4)

    @harami_vid = HaramiVid.create_basic!(title: "test vid1", langcode: "en", is_orig: true, uri: "https://youtu.be/abcde1234")
    @hvmas = []
    @hvmas[0] = HaramiVidMusicAssoc.create!(harami_vid_id: @harami_vid.id, music_id: @music1.id, timing: 50)
    @hvmas[1] = HaramiVidMusicAssoc.create!(harami_vid_id: @harami_vid.id, music_id: @music2.id, timing: 70)

    @harami_vid.event_items << @evit

    @amps = {harami: [], art3: []}
    @prole_inst   = play_roles(:play_role_inst_player_main)
    @prole_singer = play_roles(:play_role_singer)
    @prole_dancer = play_roles(:play_role_dancer)
    @prole_host   = play_roles(:play_role_host)
    @inst_piano   = instruments(:instrument_piano)
    @inst_organ   = instruments(:instrument_organ)
    @inst_guitar  = instruments(:instrument_guitar)
    @inst_vocal   = instruments(:instrument_vocal)
    @inst_body    = instruments(:instrument_human_body)
    @inst_talk    = instruments(:instrument_talk)
    @inst_na      = instruments(:instrument_not_applicable)

    @amps[:harami][0] = ArtistMusicPlay.create!(event_item_id: @evit.id, music_id: @music1.id, artist_id: @harami.id, play_role_id: @prole_inst.id, instrument_id: @inst_piano.id)  # piano
    @amps[:harami][1] = @amps[:harami][0].dup
    @amps[:harami][1].update!(instrument: @inst_organ)  # dance
    @amps[:harami][2] = @amps[:harami][0].dup
    @amps[:harami][2].update!(play_role_id: @prole_host.id,   instrument: @inst_talk)  # talk as the Host
    @amps[:harami][3] = @amps[:harami][0].dup
    @amps[:harami][3].update!(music_id: @music2.id)  # for Music2, piano

    @amps[:art3][0] = @amps[:harami][0].dup
    @amps[:art3][0].artist = @artist3
    @amps[:art3][0].update!(instrument_id: @inst_piano.id, play_role_id: @prole_inst.id)  # 4-hands play
    @amps[:art3][1] = @amps[:art3][0].dup
    @amps[:art3][1].update!(instrument_id: @inst_guitar.id) # and guitar

    @harami_vid.reload
    @evit.reload

    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @def_index_params = {
      "event_item_id"=>@evit.id.to_s,
      "music_id"=>@music1.id.to_s,
      "artist_id"=>@harami.id.to_s,
      ### Below from here would not be specified in GET call for index (or edit).  But I lay them out so that they won't be forgotten in testing create/update calls...
      "play_role_id"=>nil,
      "instrument_id"=>nil,
      "contribution_artist"=>nil,
      "cover_ratio"=>nil,
      "note"=>nil,
      "to_destroy"=>nil,
    }.with_indifferent_access
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index and post create" do
    hsnew = {note: "newno"}
    get artist_music_plays_edit_multis_path, params: {artist_music_play: @def_index_params}
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get artist_music_plays_edit_multis_path, params: {artist_music_play: @def_index_params}
    assert_response :success

    tmp = @amps[:harami][2].dup
    tmp.event_item= nil
    assert_raise(RuntimeError, "test of internal utitility-method fails..."){
      _build_prm_hash(@amps[:harami][0], tmp) }

    tmp = @amps[:harami][2].dup
    tmp.play_role = nil
    assert_raise(RuntimeError, "test of internal utitility-method fails..."){
      _build_prm_hash(@amps[:harami][0], tmp) }

    tmp = @amps[:harami][2].dup
    assert_equal ["0", @amps[:harami][0].id.to_s], _build_prm_hash(@amps[:harami][0], tmp)["instrument_id"].keys.sort, "test of keys of internal utitility-method fails..."

    ## no create test
    hsin1 = @def_index_params.merge(_build_prm_hash(@amps[:harami][0..1]))
    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_difference("ArtistMusicPlay.count", 0) do
        post artist_music_plays_edit_multis_path(params: {artist_music_play: hsin1})
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      end
    end

    harami4 = @amps[:harami][0].dup  # new_record
    harami4.instrument = instruments(:instrument_violin)
    harami4.cover_ratio = new_cover4 = 0.5
    harami4.note = "harami4--note"
    hsin2 = @def_index_params.merge(_build_prm_hash(harami4, *(@amps[:harami][0..1])))
    oldtxt = @amps[:harami][0].note
    newtxt = "newtxt1"
    hsin2["note"][@amps[:harami][0].id.to_s] = newtxt
    assert( oldtxt == @amps[:harami][0].note )
    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_difference("ArtistMusicPlay.count", 1) do
        post artist_music_plays_edit_multis_path(params: {artist_music_play: hsin2})
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        follow_redirect!
        flash_regex_assert(/Created 1, updated 1, .*\bdestroyed 0\b/i, type: :success) # defined in test_helper.rb
        assert_equal newtxt, @amps[:harami][0].reload.note
      end
    end

    haraminew4 = ArtistMusicPlay.last
    %w(instrument cover_ratio note).each do |ek|
      assert_equal harami4.send(ek), haraminew4.send(ek)
    end
    refute haraminew4.new_record?, 'sanity check' 

    hsin = hsin3 = @def_index_params.merge(_build_prm_hash(haraminew4, *(@amps[:harami][0..1]), to_destroy: [haraminew4.id]))
    cr_haraminew4 = haraminew4.cover_ratio
    hsin3["cover_ratio"][haraminew4.id.to_s] = -3  # this should result in failure
    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_no_difference("ArtistMusicPlay.count") do
        post artist_music_plays_edit_multis_path(params: {artist_music_play: hsin})
        assert_response :unprocessable_content
        flash_regex_assert(/\bCover(\s|_|)ratio must be greater than or equal to 0\b/i) # defined in test_helper.rb
      end
    end

    hsin = hsin3 = @def_index_params.merge(_build_prm_hash(haraminew4, *(@amps[:harami][0..1]), to_destroy: [haraminew4.id]))
    hsin3["note"][@amps[:harami][1].id.to_s] = newnote3 = "changed3"
    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_difference("ArtistMusicPlay.count", -1) do
        post artist_music_plays_edit_multis_path(params: {artist_music_play: hsin})
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        follow_redirect!
        flash_regex_assert(/Created 0, updated 1, .*\bdestroyed 1\b/i, type: :success) # defined in test_helper.rb
      end
    end
    refute ArtistMusicPlay.exists?(haraminew4.id)
    assert_equal newnote3, @amps[:harami][1].reload.note
    assert_equal cr_haraminew4, haraminew4.cover_ratio, "should have not changed, but..."
  end
 

  test "should get edit and patch create" do
    hsnew = {note: "newno"}
    get edit_artist_music_plays_edit_multi_path(@amps[:harami][0])
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@editor_ja, @moderator_ja, @trans_moderator].each do |user|
      sign_in user
      get edit_artist_music_plays_edit_multi_path(@amps[:harami][0])
      assert_response :redirect
      assert_redirected_to root_path
      sign_out user
    end

    sign_in @editor_harami
    get edit_artist_music_plays_edit_multi_path(@amps[:harami][0])
    assert_response :success
    hs = %i(event_item music artist).map{|i| [i, @amps[:harami][0].send(i)]}.to_h
    now_amps = ArtistMusicPlay.where(hs).distinct
    assert_equal 3, (namps = now_amps.count)
    assert_equal namps, css_select("table#table_main_form_artist_music_plays_edit_multis tr.edit_existing").size
    exp = now_amps.map(&:id).sort
    assert_equal exp, @amps[:harami][0..2].map(&:id).sort, 'testing setup...'
    assert_equal exp, css_select("table#table_main_form_artist_music_plays_edit_multis tr.edit_existing td.cell-model-id").map{|i| i.text.to_i}.sort, "In Edit screen, there should be two rows for existing AMPs, but..."

    upd0 = @amps[:harami][0].updated_at

    ## no change test
    hsin = hsin1 = @def_index_params.merge(_build_prm_hash(@amps[:harami][0..2]))
    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_difference("ArtistMusicPlay.count", 0) do
        patch artist_music_plays_edit_multi_path(@amps[:harami][0], params: {artist_music_play: hsin})
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      end
    end
    follow_redirect!
    flash_regex_assert(/Created 0, updated 0, .*\bdestroyed 0\b/i, type: :success) # defined in test_helper.rb
    assert_equal upd0, @amps[:harami][0].reload.updated_at

    ## 1 update and 1 destroy
    hs = _build_prm_hash(@amps[:harami][0..2], to_destroy: [@amps[:harami][1].id])
    hsin = hsin1 = @def_index_params.merge(hs)
    hsin1["note"][@amps[:harami][0].id.to_s] = newnote1 = "changed1"
    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_difference("ArtistMusicPlay.count", -1) do
        patch artist_music_plays_edit_multi_path(@amps[:harami][0], params: {artist_music_play: hsin})
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      end
    end
    follow_redirect!
    flash_regex_assert(/Created 0, updated 1, .*\bdestroyed 1\b/i, type: :success) # defined in test_helper.rb
    assert_operator upd0, :<, @amps[:harami][0].reload.updated_at
    assert_equal newnote1, @amps[:harami][0].reload.note
    refute ArtistMusicPlay.exists?(@amps[:harami][1].id)

    ## create a new one
    harami4 = @amps[:harami][0].dup  # new_record
    harami4.instrument = instruments(:instrument_violin)
    harami4.cover_ratio = new_cover4 = 0.5
    harami4.note = "harami4--note"

    @amps[:harami][0].reload
    hs = _build_prm_hash(harami4, @amps[:harami][0], @amps[:harami][2])  # @amps[:harami][1] has been destroyed.
    hsin = hsin2 = @def_index_params.merge(hs)
    oldnote = @amps[:harami][0].note
    hsin2["note"][@amps[:harami][0].id.to_s] = newnote2 = "changed2"

    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_difference("ArtistMusicPlay.count", 1) do
        patch artist_music_plays_edit_multi_path(@amps[:harami][0], params: {artist_music_play: hsin})
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        follow_redirect!
        flash_regex_assert(/Created 1, updated 1, .*\bdestroyed 0\b/i, type: :success) # defined in test_helper.rb
        assert_equal newnote2, @amps[:harami][0].reload.note
      end
    end

    assert_equal harami4.instrument, ArtistMusicPlay.last.instrument
    harami4 = ArtistMusicPlay.last

    ## not specifying Instrument => failure
    hs = _build_prm_hash(harami4, @amps[:harami][0], @amps[:harami][2])  # All existing records
    hsin = hsin3 = @def_index_params.merge(hs)
    hsin3["instrument_id"][harami4.id.to_s] = ""

    assert_no_difference("HaramiVid.count + HaramiVidEventItemAssoc.count") do
      assert_no_difference("ArtistMusicPlay.count") do
        patch artist_music_plays_edit_multi_path(@amps[:harami][0], params: {artist_music_play: hsin})
        assert_response :unprocessable_content
        flash_regex_assert(/\Instrument must exist\b/i) # defined in test_helper.rb
      end
    end

  end

  private

    # Returns Hash to pass to params
    #
    # One of the {ArtistMusicPlay}-s can be new_record?
    # whose ID is treated as 0.
    #
    # @param amps [Array<ArtistMusicPlay>]
    # @param to_destroy: [Array<Integer>] IDs of {ArtistMusicPlay}-s to destroy
    # @return [Hash] (with_indifferent_access) to pass to params; e.g., where a new record and AMP-ID=71:
    #    {"event_item_id" => 44, "music_id" => 55, "artist_id" => 66,
    #     "play_role_id" => {"0" => 456", "71" => 123}, "instrument_id" =>  {"0" => 474", "71" => 29},
    #     "contribution_artist" => {"0" => 0.5, "71" => 1.0}, "cover_ratio" => {...}, "note" => {...}} 
    def _build_prm_hash(*amps, to_destroy: [])
      amps = amps.flatten
      basekeys = %w(event_item_id music_id artist_id)

      hsret = {}

      amps.each do |amp|
        (basekeys + %w(play_role_id instrument_id contribution_artist cover_ratio note)).each do |ek|
          val = amp.send(ek)
          if basekeys.include?(ek)
            hsret[ek] ||= val
            raise "inconsistent #{ek}: #{hsret[ek].inspect} != #{val.inspect} for amps=#{amps.inspect}" if hsret[ek] != val
            next
          end

          hsret[ek] ||= {}
          hsret[ek][(amp.id || 0).to_s] ||= val

          case ek
          when *(%w(play_role_id instrument_id))
            raise "No significant #{ek}: #{amps.inspect}" if val.blank?
          end
        end
      end

      if !to_destroy.empty?
        hsret["to_destroy"] = to_destroy.map{|i| [i.to_s, "true"]}.to_h
      end

      hsret
    end
end
