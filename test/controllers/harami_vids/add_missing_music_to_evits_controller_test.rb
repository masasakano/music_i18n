# coding: utf-8
require "test_helper"

class EventItems::AddMissingMusicsControllerTest < ActionDispatch::IntegrationTest
  include HaramiVids::AddMissingMusicToEvitsHelper # for unit testing

  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "use_cache_test" => true,
    }.with_indifferent_access

    @def_create_params = @def_update_params.merge({
      "uri_youtube" => "https://www.youtube.com/watch?v=hV_L7BkwioY", # HARAMIchan Zenzenzense; harami1129s(:harami1129_zenzenzense1).link_root
    }.with_indifferent_access)
    @h1129 = harami1129s(:harami1129_sting1)
    @harami = artists(:artist_harami)
    @artist_ai = artists(:artist_ai)
    @channel = Channel.default(:HaramiVid)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should patch update" do
    assert_equal @harami, Artist.default(:HaramiVid), 'sanity check'

    @h1129.insert_populate

    assert @h1129.ins_song.present?
    hvid = @h1129.harami_vid
    assert hvid
    assert_equal @channel, hvid.channel

    @channel.update!(note: "Test-note" + (@channel.note || ""))
    note_be4 = @channel.note

    muss = []
    arts = []
    hvma = {}
    evits = [nil, nil]
    amps = []

    # sanity checks
    assert (muss[0]=hvid.musics.first)
    muss[0].update!(note: "Created-"+muss[0].title)
    assert (arts[0]=hvid.artists.first)
    assert (evits[0]=hvid.event_items.first)
    assert_equal 1, evits[0].artist_music_plays.size, 'sanity check'

    amps[0] = evits[0].artist_music_plays.first
    assert_equal evits[0], amps[0].event_item
    assert_equal @harami, amps[0].artist
    assert hvid.uri.present?

    hvid.reload
    assert_equal 2, @channel.translations.size, 'sanity check'

    assert_equal 1, hvid.harami_vid_music_assocs.size
    hvma[muss[0].id] = hvid.harami_vid_music_assocs.first
    assert_equal muss[0], hvma[muss[0].id].music, 'sanity check'

    muss[1] = musics(:music_story)
    muss[2] = musics(:music_robinson)
    muss[3] = musics(:music_light)

    # Associates 3 more Musics to HaramiVid
    (1..3).each do |i|
      assert_difference("HaramiVidMusicAssoc.count") do
        hvid.musics << muss[i]
      end
      hvma[muss[i].id] = HaramiVidMusicAssoc.last
      hvma[muss[i].id].update(timing: i*100)  # 100s, 200s, 300s
      # NOTE: hvma[muss[0].id].timing == nil
    end

    evits[1] = evits[0].dup
    evits[1].update!(machine_title: evits[0].machine_title+"-2")
    assert_difference("HaramiVidEventItemAssoc.count") do
      hvid.event_items << evits[1]
    end

    assert_difference("ArtistMusicPlay.count") do
      amps << ArtistMusicPlay.create!(event_item: evits[1], artist: @artist_ai, music: muss[1], play_role: play_roles(:play_role_singer), instrument: instruments(:instrument_vocal))  # AI singing Story in EventItem-2 (=evits[1]).
    end
    evits[0..1].each do |eevit|
      eevit.artist_music_plays.reset
    end

    assert_equal 1,       evits[0].artist_music_plays.count
    assert_equal muss[0], (amp=evits[0].artist_music_plays.first).music
    assert_equal @harami, amp.artist
    assert_equal 1,       evits[1].artist_music_plays.count
    assert_equal muss[1], (amp=evits[1].artist_music_plays.first).music
    assert_equal @artist_ai, amp.artist
    muss[2..3].each do |emu|
      evits.each do |eevit|
        refute eevit.artist_music_plays.where(music_id: emu.id).exists?
      end
    end
    hvid.reload

    ### unit tests
    artest = missing_musics_from_evits(harami_vid: hvid, artist: @harami)
    assert_equal 3, artest.size
    assert_equal muss[1..3].map(&:id).sort, artest.map(&:id).sort
    artest = missing_musics_from_evits(harami_vid: hvid, artist: nil)
    assert_equal 2, artest.size
    assert_equal muss[2..3].map(&:id).sort, artest.map(&:id).sort

    set_missing_music_ids(harami_vid: hvid)
    assert_equal muss[2..3].map(&:id).sort, hvid.missing_music_ids.sort, "should agree, but : #{hvid.missing_music_ids.inspect}"

    ###
    # Now HaramiVid "hvid" has
    #   * Musics associated (one of which has nil timing in HaramiVidMusicAssoc).
    #   * 2 EventItems associated
    #     * In evits[0], Harami plays muss[0] with Piano                          (as defined in an ArtistMusicPlay)
    #     * In evits[1], AI     plays muss[1] with Vocal, but Harami does nothing (as defined in another ArtistMusicPlay)
    #   * muss[2..3] has no associations with ArtistMusicPlay-s.
    #

    hsin = {
      musics_event_item_id: evits[0].id.to_s,
      missing_music_ids: [""]+muss[2..3].map{|emu| emu.id.to_s},  # "" is usually prepended in simple_form
    }.with_indifferent_access

    ## sign_in mandatory
    patch harami_vids_add_missing_music_to_evit_url(hvid), params: { harami_vid: {add_missing_music_to_evit: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    get harami_vid_url(hvid)
    assert_empty css_select("div.add_missing_musics"), "the form section (to submit updating of Music-EventItem associations) should not be displayed, but..."

    patch harami_vids_add_missing_music_to_evit_url(hvid), params: { harami_vid: {add_missing_music_to_evit: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified
    sign_in @editor_harami

    get harami_vid_url(hvid)
    assert_response :success
    assert_includes css_select("div.add_missing_musics").text, "Missing Musics in EventItem-HARAMIchan"
    assert_equal 2, css_select("div.add_missing_musics").size, "2 sections should exist because of 2 EventItems, but..."
    (0..3).each do |i_muss|
      input_id_css = sprintf("harami_vid_add_missing_music_to_evit_missing_music_ids_%s", muss[i_muss].id)
      csssel = css_select("div.add_missing_musics form input#"+input_id_css)
      if 0 == i_muss
        assert_equal 0, csssel.size, "no choice displayed for already ArtistMusicPlay-registered Music, but..."
      else
        assert_equal 2, csssel.size, "2 same inputs for 2 EventItems, but..."
        if 1 == i_muss
          assert_nil              csssel[0]["checked"]
        else
          assert_equal "checked", csssel[0]["checked"]
        end
      end
    end

    assert_match(/#{Regexp.quote(muss[2].title_or_alt(langcode: I18n.locale, lang_fallback_option: :either))}/, css_select("div.add_missing_musics").text)  # spaces are omitted in "text", so the word boundary does not make sense.

    assert_raises(ActiveRecord::RecordNotFound){
      patch harami_vids_add_missing_music_to_evit_url(hvid), params: { harami_vid: {add_missing_music_to_evit: hsin.merge({missing_music_ids: [Music.order(:id).last.id+1]}) } }
    }
    assert_raises(StandardError){
      # Tests of Music that exists but is not associated to this HaramiVid through HaramiVidMusicAssoc  => should fail.
      patch harami_vids_add_missing_music_to_evit_url(hvid), params: { harami_vid: {add_missing_music_to_evit: hsin.merge({missing_music_ids: [Music.unknown.id]}) } }
    }

    assert_no_difference("Music.count*1000 + Artist.count*100 + Engage.count*10 + HaramiVidMusicAssoc.count") do
      assert_difference("ArtistMusicPlay.count*1000 + Event.count*100 + EventItem.count*10", 2000) do
        assert_no_difference("HaramiVidEventItemAssoc.count*10 + HaramiVid.count*1") do
          assert_no_difference("Translation.count") do
            patch harami_vids_add_missing_music_to_evit_url(hvid), params: { harami_vid: {add_missing_music_to_evit: hsin } }
            assert_response :redirect
          end
        end
      end
    end
    assert_redirected_to harami_vids_add_missing_music_to_evit_url(hvid, harami_vid: {add_missing_music_to_evit: {musics_event_item_id: evits[0].id} })

    evits[0].reload
    assert_equal 3, (amp0s=evits[0].artist_music_plays).count
    assert_equal [muss[0], *(muss[2..3])].map(&:id).sort, amp0s.pluck(:music_id).flatten.sort
    assert_equal 1, (arttmp=amp0s.pluck(:artist_id).flatten.uniq).size
    assert_equal @harami.id, arttmp.first

    evits[1].reload
    assert_equal 1,       evits[1].artist_music_plays.count  # no change

    follow_redirect!
    assert_includes css_select("div.add_missing_musics").text, "Missing Musics in EventItem-HARAMIchan"
    refute_match(/#{Regexp.quote(muss[2].title)}/, css_select("div.add_missing_musics").text)
  end
end
