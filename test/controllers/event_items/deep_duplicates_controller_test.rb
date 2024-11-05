# coding: utf-8
require 'test_helper'

class EventItems::DeepDuplicatesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @channel = channels(:channel_haramichan_youtube_main)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @h1129 = harami1129s(:harami1129_zenzenzense1)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should post create" do
        # See /test/models/harami1129_test.rb
    @h1129.insert_populate

    assert @h1129.ins_song.present?
    hvid = @h1129.harami_vid
    assert hvid
    assert_equal @channel, hvid.channel
    hvid.update!(release_date: Date.current - 3.days)

    @channel.update!(note: "Test-note" + (@channel.note || ""))
    note_be4 = @channel.note

    # sanity checks
    muss = []
    assert_equal 1, hvid.musics.count
    muss[0] = hvid.musics.first
    assert_equal 1, hvid.event_items.count

    # EventItem created and adjusted for Time and Weight
    evit_from = evit11 = hvid.event_items.first
    evit_from.start_time     = Time.current - 2.days
    evit_from.start_time_err = 56
    evit_from.duration_minute     = 40.minutes.in_minutes
    evit_from.duration_minute_err = 12
    evit_from.weight = 0.4
    evit_from.save!

    assert_equal 1, hvid.artist_collabs.count  # Collab Artist for EventItem-s through ArtistMusicP lay-s
    arts = []
    arts[0] = hvid.artist_collabs.first
    assert_equal 1, hvid.artist_music_plays.count
    amps_from = []
    amps_from << hvid.artist_music_plays.first
    assert_equal evit_from, amps_from[0].event_item
    assert_equal muss[0],   amps_from[0].music
    assert_equal Artist.default(:HaramiVid),     arts[0]
    assert_equal Instrument.default(:HaramiVid), amps_from[0].instrument
    assert_equal Instrument.default(:HaramiVid), instruments(:instrument_piano), "sanity check to ensure sure this differs from the others"
    assert_equal PlayRole.default(:HaramiVid),  amps_from[0].play_role
    assert_equal PlayRole.default(:HaramiVid),  play_roles(:play_role_inst_player_main), "sanity check to ensure sure this differs from the others"
    assert_nil   amps_from[0].contribution_artist
    assert hvid.uri.present?
    hvid.reload

    # an extra HaramiVid, and also its associated ArtistMusicPlay, to associate to this EventItem
    # Ideally, all Musics for this should be associated to hvid above through HaramiVidMusicAssoc;
    # however, it is deliberately not the case here.
    hvid_extra = HaramiVid.create_basic!(title: "extra-vid", langcode: "en", is_orig: "true", uri: "http://youtu.be/abcdefg789", release_date: Date.current)
    hvid_extra.event_items << evit11

    ## further preparation
    #
    # * Ev1 > EvIt11 (==evit11==evit_from)
    #   * (For this HaramiVid through HaramiVidMusicAssoc => inconsistent)
    #     * AMP0(PrimaryArtist, Mu0, PlayRoleInst, InstPiano)   # existing: amps_from[0]
    #     * AMP1(PrimaryArtist, Mu0, PlayRoleHost, Talk)
    #     * AMP2(Artist1,       Mu0, PlayRoleSinger, Body)
    #     * AMP3(Artist1,       Mu0, PlayRoleGuest, Talk)
    #     * AMP4(Artist1,       Mu1, PlayRoleSinger, Body)
    #   * (HaramiVid-extra through HaramiVidMusicAssoc) (hvid_extra)  # => this (and its AMP) will not be included in the result!
    #     * AMP11(Artist1,      Mu3, PlayRoleSinger, Body)  # => AMP3, but Mu3
    # * Ev1 > EvIt12
    #     * AMP5(PrimaryArtist, Mu0, PlayRoleInst, InstPiano)   # => AMP0
    #     * AMP6(PrimaryArtist, Mu0, PlayRoleInst, InstKeyboard) # unique
    #     * AMP7(Artist1,       Mu0, PlayRoleSinger, Vocal)      # => AMP2
    #     * AMP8(PrimaryArtist, Mu2, PlayRoleInst, InstPiano)   # unique
    # * Ev2 > EvIt23
    #     * AMP9(PrimaryArtist, Mu0, PlayRoleHost, Talk)       # => AMP1
    #     * AMP10(PrimaryArtist,Mu2, PlayRoleInst, InstPiano)  # => AMP8
    #
    evit12 = evit_from.dup
    evit12.update!(machine_title: evit_from.machine_title+"-2")
    ev3 = events(:ev_harami_budokan2022_soiree)
    evit23 = evit_from.dup
    evit23.update!(event: ev3, machine_title: ev3.title.gsub(/ /, "_")+"-1")
    assert_equal evit11.event, evit12.event, "sanity check"
    refute_equal evit11.event, ev3, "sanity check"

    arts[1] = artists(:artist_proclaimers)
    refute_equal arts[0], arts[1], "sanity check"
    muss[1] = musics(:music_light)
    muss[2] = Music.create_basic!(title: "500 miles", langcode: "en", is_orig: true, year: 1985)
    _ = Engage.create!(artist: arts[1], music: muss[2], engage_how: EngageHow.default(:HaramiVid))
    muss[2].artists.reset
    arts[1].musics.reset
    refute_equal muss[1], muss[0], "sanity check"
    refute_equal muss[2], muss[0], "sanity check"
    hvid.musics << muss[1]  # through HaramiVidMusicAssoc
    hvid.musics << muss[2]  # through HaramiVidMusicAssoc

    muss[3] = musics(:music_robinson)
    _ = Engage.create!(artist: arts[1], music: muss[3], engage_how: EngageHow.default(:HaramiVid))

    pr_singer= play_roles(:play_role_singer)
    pr_host  = play_roles(:play_role_host)
    pr_guest = play_roles(:play_role_guest)
    inst_kbd  = instruments(:instrument_keyboard)
    inst_body = instruments(:instrument_human_body)
    inst_talk = instruments(:instrument_talk)
    amps_from[1] = _dupped_modified_create!(amps_from[0], play_role: pr_host, instrument: inst_talk)
    amps_from[2] = _dupped_modified_create!(amps_from[0], artist: arts[1], play_role: pr_singer, instrument: inst_body)
    amps_from[3] = _dupped_modified_create!(amps_from[0], artist: arts[1], play_role: pr_guest,  instrument: inst_talk)
    amps_from[4] = _dupped_modified_create!(amps_from[0], artist: arts[1], music: muss[1], play_role: pr_singer, instrument: inst_body, contribution_artist: 3.4, cover_ratio: 0.56, note: "a new note for test")
    amps_from[5] = _dupped_modified_create!(amps_from[0], event_item: evit12)
    amps_from[6] = _dupped_modified_create!(amps_from[0], event_item: evit12, instrument: inst_kbd)
    amps_from[7] = _dupped_modified_create!(amps_from[2],event_item: evit12)
    amps_from[8] = _dupped_modified_create!(amps_from[0], event_item: evit12, artist: arts[1], music: muss[2])
    amps_from[9] = _dupped_modified_create!(amps_from[1],event_item: evit23)
    amps_from[10]= _dupped_modified_create!(amps_from[8],event_item: evit23)
    amps_from[11]= _dupped_modified_create!(amps_from[4],music: muss[3])

    hvid_extra.music_plays.reset
    muss.each do |em|
      # hvid_extra.musics << em if hvid_extra.music_plays.include?(em)  # through HaramiVidMusicAssoc
      hvid_extra.musics << em if hvid_extra.music_plays.where("artist_music_plays.music_id = ?", em.id).exists? # through HaramiVidMusicAssoc
      # hvid_extra is fully consistent with evit11
    end

    ([evit11, evit12, evit23]+muss+arts).each do |em|
      em.artist_music_plays.reset
    end

    assert_equal 6, evit11.artist_music_plays.count
    assert_equal 4, evit12.artist_music_plays.count
    assert_equal 2, evit23.artist_music_plays.count
    assert_equal 8, muss[0].artist_music_plays.count
    assert_equal 1, muss[1].artist_music_plays.count
    assert_equal 2, muss[2].artist_music_plays.count
    assert_equal 1, muss[3].artist_music_plays.where(event_item_id: evit11.id).count
    assert_equal 5, arts[0].artist_music_plays.where(music_id: muss[0].id).count
    assert_equal 3, arts[1].artist_music_plays.where(music_id: muss[0].id).count
    assert_equal 1, arts[1].artist_music_plays.where(music_id: muss[1].id).count
    assert_equal 1, arts[1].artist_music_plays.where(music_id: muss[3].id).count

    assert_equal  6, hvid.artist_music_plays.count
    hvid.event_items << evit12
    hvid.event_items << evit23
    hvid.reload
    hvid_extra.reload
    assert_equal 12, hvid.artist_music_plays.count
    assert_equal  6, hvid_extra.artist_music_plays.count
    assert_equal  3, hvid.musics.count        # muss[0..2], i.e., deliberate inconsistency, though muss[3] should be associated through HaramiVidMusicAssoc when it is associated via HaramiVidEventItemAssoc => ArtistMusicPlay
    assert_equal  3, hvid_extra.musics.count  # muss[0..1, 3] b/c neither evit12 nor evit23 is associated to this HaramiVid

    hsin = {event_item_id: evit11.id.to_s, harami_vid_id: hvid.id.to_s}.with_indifferent_access

    ## sign_in mandatory
    post event_items_deep_duplicates_url, params: { event_item: { deep_duplicates_controller: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    post event_items_deep_duplicates_url, params: { event_item: { deep_duplicates_controller: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified.
    # Same Japanese Translation, but English Translation is added.
    sign_in @editor_harami
    #sign_in @moderator_all
    #sign_in(user=@syshelper)

    assert_difference("ArtistMusicPlay.count", 6) do  # 4 Artist's Music-Event-Play for 2 Musics, 2 Instruments, 2 Artists
      assert_difference("Music.count + Artist.count + Engage.count", 0) do
        #assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 11) do  # comments out because this might change in the future.
        assert_difference("HaramiVidEventItemAssoc.count", 2) do  # for hvid and hvid_extra
          assert_difference("Event.count*11 + EventItem.count", 1) do  # 1 Event + 1 EventItem  (Event created because Place is new for the unknown Event!  If Event was not unknown, the existing one should be used in default. EventItem is an unknown one and default one)
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count*10 + Harami1129.count") do
                post event_items_deep_duplicates_url, params: { event_item: { deep_duplicates_controller: hsin } }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end
    assert_redirected_to harami_vid_path(hvid)

    evit = evit_new = EventItem.last  # order(created_at: :desc).first

    %w(start_time start_time_err duration_minute duration_minute_err).each do |attr|
      assert      (exp=evit11.send(attr)).present?
      assert_equal exp, evit.send(attr)
    end

    assert_match(/^copy-/, evit.machine_title)  # "copy" == EventItems::PREFIX_MACHINE_TITLE_DUPLICATE

    assert      evit11.weight
    assert_nil  evit.weight

    assert_equal 2,    evit.harami_vids.count
    assert_equal hvid, evit.harami_vids.order(:release_date).first
    assert_equal 3,    evit.musics.count
    assert_equal muss.values_at(0,1,3).sort{|a,b| a.id <=> b.id}, evit.musics.order("musics.id")
    assert_equal arts.sort{      |a,b| a.id <=> b.id}, evit.artists.order("artists.id")

    assert_equal 6, evit.artist_music_plays.count

    # AMP0, AMP1
    assert_equal 2, (rela = evit.artist_music_plays.where(artist_id: arts[0].id)).count
    assert_equal 1, (ar=rela.pluck(:music_id).flatten.uniq).size  # there are 2 and both have muss[0]
    assert_equal muss[0].id, ar.first  # only one element
    assert_equal amps_from[0..1].map{|em| [em.play_role_id, em.instrument_id]}.sort, rela.pluck(:play_role_id, :instrument_id).sort

    # AMP2, AMP3
    assert_equal 2, (rela = evit.artist_music_plays.where(artist_id: arts[1].id, music_id: muss[0].id)).count
    assert_equal amps_from[2..3].map{|em| [em.play_role_id, em.instrument_id]}.sort, rela.pluck(:play_role_id, :instrument_id).sort

    # AMP4
    assert_equal 1, (rela = evit.artist_music_plays.where(music_id: muss[1].id)).count
    amp = rela.first
    assert_equal arts[1],   amp.artist
    assert_equal pr_singer, amp.play_role
    assert_equal inst_body, amp.instrument

    %i(contribution_artist cover_ratio note).each do |ek|
      assert       amps_from[4].send(ek).present?, "ek=#{ek.inspect} / #{amps_from[8].inspect}"
      assert_equal amps_from[4].send(ek), amp.send(ek), "#{ek} is inconsistent..."
    end


    ######## Second time
    # only the difference is the machine_title, which must be unique.

    assert_difference("ArtistMusicPlay.count", 6) do  # 4 Artist's Music-Event-Play for 2 Musics, 2 Instruments, 2 Artists
      assert_difference("Music.count + Artist.count + Engage.count", 0) do
        #assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 11) do  # comments out because this might change in the future.
        assert_difference("HaramiVidEventItemAssoc.count", 2) do  # for hvid and hvid_extra
          assert_difference("Event.count*11 + EventItem.count", 1) do  # 1 Event + 1 EventItem  (Event created because Place is new for the unknown Event!  If Event was not unknown, the existing one should be used in default. EventItem is an unknown one and default one)
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count*10 + Harami1129.count") do
                post event_items_deep_duplicates_url, params: { event_item: { deep_duplicates_controller: hsin } }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end
    assert_redirected_to harami_vid_path(hvid)

    evit = evit_new = EventItem.last  # order(created_at: :desc).first

    %w(start_time start_time_err duration_minute duration_minute_err).each do |attr|
      assert      (exp=evit11.send(attr)).present?
      assert_equal exp, evit.send(attr)
    end

    assert_match(/^copy1-/, evit.machine_title)  # "copy" == EventItems::PREFIX_MACHINE_TITLE_DUPLICATE
    assert      evit11.weight
    assert_nil  evit.weight

    sign_out @editor_harami
  end

  private

    # @example
    #    amp_orig = harami_vid.artist_music_plays.first
    #    amp_created = _dupped_modified_create!(amp_orig, event_item: my_evit2, instrument: my_inst3)
    #
    # @return [ArtistMusicPlay] dup-ped but modified.
    def _dupped_modified_create!(amp_ref, **kwds)
      bind = caller_locations(1,1)[0]  # Ruby 2.0+
      caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
      # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

      ret = amp_ref.dup
      begin
        ret.update!(**kwds)
      rescue
        warn "ERROR(#{caller_info}): : kwds = "+kwds.inspect
        raise
      end
      ret
    end
end
