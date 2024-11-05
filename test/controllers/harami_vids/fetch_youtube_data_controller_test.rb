# coding: utf-8
require "test_helper"

# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : set this to ignore marshal but access Youtube-API
#   Some tests are performed only with ENV["SKIP_YOUTUBE_MARSHAL"]=1
#
class FetchYoutubeDataControllerTest < ActionDispatch::IntegrationTest
  include ModuleYoutubeApiAux  # for unit testing

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
    @h1129 = harami1129s(:harami1129_zenzenzense1)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should create" do
    hsin = {}.merge(@def_create_params.merge).with_indifferent_access  # "use_cache_test" => true

    ## sign_in mandatory
    post harami_vids_fetch_youtube_data_path, params: { harami_vid: { fetch_youtube_datum: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    post harami_vids_fetch_youtube_data_path, params: { harami_vid: { fetch_youtube_datum: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    assert ENV["YOUTUBE_API_KEY"].present?, "Environmental variable YOUTUBE_API_KEY is not set, which is essential for this test."

    ## Editor harami is qualified
    sign_in @editor_harami

    assert_difference("Music.count*1000 + Artist.count*100 + Engage.count*10 + HaramiVidMusicAssoc.count", 0) do
      assert_difference("ArtistMusicPlay.count*1000 + Event.count*100 + EventItem.count*10", 110) do
        assert_difference("HaramiVidEventItemAssoc.count*10 + HaramiVid.count*1", 11) do
          assert_difference("Translation.count", 3) do  # JA/EN for new HaramiVid, and JA for new Event "都庁(東京都/日本)でのイベント..."
            assert_no_difference("Channel.count") do
              post harami_vids_fetch_youtube_data_path, params: { harami_vid: { fetch_youtube_datum: hsin } }
              assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              hvid = HaramiVid.last
              assert_redirected_to hvid
            end
          end
        end
      end
    end

    hvid = HaramiVid.last

    assert_equal @h1129.link_root, File.basename(hvid.uri), "sanity check..."
    assert_empty hvid.musics
    #assert_equal @h1129.song,   hvid.musics.first.title
    #assert_equal @h1129.singer, hvid.artists.first.title
    assert_equal @h1129.title,  hvid.title
    assert_equal channels(:channel_haramichan_youtube_main), hvid.channel
    assert_equal Event.default(:HaramiVid, place: places(:tocho)), hvid.event_items.first.event
    assert       hvid.release_date
    assert_equal hvid.release_date, hvid.event_items.first.publish_date

    sign_out @editor_harami
  end

  test "should update" do
    # See /test/models/harami1129_test.rb
    @h1129.insert_populate

    assert @h1129.ins_song.present?
    hvid = @h1129.harami_vid
    assert hvid

    hvid.update!(note: "Test-note" + (hvid.note || ""))
    note_be4 = hvid.note

    mus = hvid.musics.first
    art = hvid.artists.first
    evit = hvid.event_items.first
    assert evit
    evit_stime0 = evit.start_time
    assert evit_stime0
    amps  = evit.artist_music_plays
    amp   = amps.first

    # sanity checks
    assert_equal 1, amps.size
    assert mus
    assert art
    assert hvid.uri.present?
    hvid.reload
    assert_equal 1, hvid.translations.size
    tra_be4 = hvid.translations.first
    assert_equal "ja", tra_be4.langcode
    assert_nil hvid.duration
    assert_equal 1, hvid.events.count
    assert_equal 1, hvid.event_items.count
    assert   (ev_du_hr=hvid.events.first.duration_hour)
    assert(evit_du_min=hvid.event_items.first.duration_minute)
    assert_in_delta(ev_du_hr*60, evit_du_min, delta=0.001, msg="inconsistent Duration")  # For Float comparison

    channel_be4      = hvid.channel
    release_date_be4 = hvid.release_date
    assert channel_be4
    assert release_date_be4

    hsin = {}.merge(@def_update_params.merge).with_indifferent_access  # "use_cache_test" => true

    ## unit tests of ModuleYoutubeApiAux
    yid = @h1129.link_root
    assert_equal yid, get_yt_video_id(yid)
    suri = "www.youtube.com/?v="+yid+"&t=888&si=acvskf"
    assert_equal yid, get_yt_video_id(suri)
    assert_equal yid, get_yt_video_id("https://"+suri)
    assert_equal yid, get_yt_video_id(hvid)
    uristr = "https://www.example.com/abc123"
    ret = ApplicationHelper.get_id_youtube_video(uristr)
    assert_equal "abc123",      ret
    assert_equal "example.com", ret.platform
    ret = get_yt_video_id(uristr)
    assert_equal "abc123",      ret
    assert_equal "example.com", ret.platform
    ret = get_yt_video_id(hvid)
    assert_equal @h1129.link_root, ret

    ## WARNING: This always accesses Google Youtube API.
    if is_env_set_positive?("SKIP_YOUTUBE_MARSHAL") # defined in ApplicationHelper
      set_youtube  # sets @youtube; defined in ModuleYoutubeApiAux
      assert_nil get_yt_video("naiyo")
    end

    ## sign_in mandatory
    patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified
    # Same Japanese Translation, but English Translation is added.
    sign_in @editor_harami
    ModuleWhodunnit.whodunnit  #  just to (potentially) suppress mal-functioning in setting this...

    assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count") do
      assert_difference("Translation.count") do  # English Translation added.
        patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        assert_redirected_to hvid
      end
    end

    hvid.reload
    assert_equal note_be4, hvid.note
    assert_equal channel_be4,      hvid.channel
    assert_equal release_date_be4, hvid.release_date

    assert hvid.duration.present?
    assert_operator 0, :<, (hv_dura=hvid.duration), "Positive duration should have been set, but..."

    _do_check_if_duration_adjusted(hvid, ev_du_hr, evit_du_min, caller_msg="1st run")

    tras = hvid.translations
    assert_equal %w(en ja), tras.pluck(:langcode).flatten.sort
    refute_equal(*tras.pluck(:title))

    tra_en = tras.find_by(langcode: "en")
    assert_equal @editor_harami, tra_en.create_user, "(NOTE: for some reason, created_user_id is nil) User=#{@editor_harami.inspect} / ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} / PaperTrail.request.whodunnit=#{PaperTrail.request.whodunnit.inspect} / Translation="+tra_en.inspect

    evit.reload
    assert_equal evit_stime0, evit.start_time  # because the vid is from 2019-06 and EventItem#start_time is similar.

    ## 2nd and 3rd runs
    # Mostly checking Channels, but also checking EventItem parameters
    # In default this uses marshal data, but accesses Google/Youtube API if ENV["SKIP_YOUTUBE_MARSHAL"] or ENV["UPDATE_YOUTUBE_MARSHAL"] is set positive.
    # This time, only Youtube-ID of Channel should be updated after it is deliberately unset.
    hv_dura0 = hvid.duration
    evit = hvid.event_items.first
    ev   = evit.event

    dura0 = 23.hours
    evit_stime_early = Date.new(1999, 1, 1).to_time
    ev.update!(  start_time: evit_stime_early)  # much earlier date
    evit.update!(start_time: evit_stime_early)  # => this should be updated.
    ev.update!(  duration_hour:   dura0.in_hours)
    evit.update!(duration_minute: dura0.in_minutes)

    chan = hvid.channel
    %w(id_at_platform id_human_at_platform).each_with_index do |att, i_run|
      chan.update!(att => nil)
      assert_nil chan.send(att)
      prev_updated_time = chan.updated_at
  
      assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count") do
        assert_no_difference("Translation.count") do
          patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
          assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          assert_redirected_to hvid
        end
      end
  
      chan.reload
      assert_operator prev_updated_time, :<, chan.updated_at
      assert chan.send(att)
      assert_operator 3, :<=, chan.send(att).size, "#{att} should have been set, but..."

      hvid.reload
      assert_equal hv_dura0, (hv_dura2=hvid.duration)

      ev.reload
      evit.reload
      stime = evit.start_time
      assert_equal ev.start_time, evit_stime_early, "Event time should not be affected."
      refute_equal    stime,      evit_stime_early
      assert_operator stime, :>,  evit_stime_early
      assert_operator stime.to_date, :<=, hvid.release_date
      assert_operator stime.to_date, :>=, hvid.release_date - 3.months
      _do_check_if_duration_adjusted(hvid, dura0.in_hours, dura0.in_minutes, caller_msg="#{i_run+2}-st run")
    end


    ## 4th run
    # Checking updating start_time or not with HaramiVid sharing an EventItem
    evit_sdate_2yr = (hvid.release_date - 2.years)
    evit_stime_2yr = evit_sdate_2yr.to_time
    evit.update!(start_time: evit_stime_2yr)  # => this should NOT be updated this time because of other HaramiVid.

    str_unique = __method__.to_s.gsub(/(\s|[^a-z])/i, '_')
    i = 2
    tit, uri = "new vid #{i} #{str_unique}", "https://example.com/#{str_unique}_#{i}"
    hvid2_date = evit_sdate_2yr + 2.days 
    hvid2 = HaramiVid.create_basic!(title: tit, langcode: "en", is_orig: true, uri: uri, release_date: hvid2_date)
    hvid2.event_items << evit
    hvid2.musics << mus

    evit.reload
    assert_equal 2, evit.harami_vids.count, "sanity check"

    assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count + Translation.count") do
      patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
      assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      assert_redirected_to hvid
    end

    evit.reload
    stime = evit.start_time
    assert_equal stime, evit_stime_2yr, "EventItem start time should not be updated this time because of other HaramiVid, but..."


    ## 5th run
    # Checking updating start_time or not with HaramiVid sharing a Music and Event
    hvid2.event_items.destroy(evit)
    evit.reload
    assert_equal 1, evit.harami_vids.count, "sanity check"
    assert_equal 0, hvid2.event_items.count, "sanity check"
    
    evit2 = evit.dup
    evit2.update!(machine_title: EventItem.get_unique_title(__method__.to_s))
    hvid2.event_items << evit2
    assert_equal evit2, hvid2.event_items.first, "sanity check"

    assert_difference("ArtistMusicPlay.count*1000 + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count*100 + HaramiVidEventItemAssoc.count*10 + Event.count + EventItem.count + Channel.count + HaramiVid.count + Translation.count", 1000) do
      amp, hvmas = hvid2.associate_music(mus, evit2, timing: 5)  # , bang: true, update_if_exists: false)
    end
    hvid2.reload
    evit2.reload
    assert_equal 1,     evit2.harami_vids.count, "sanity check"
    assert_equal hvid2, evit2.harami_vids.first, "sanity check"
    assert_equal mus,   hvid2.musics.first,      "sanity check"

    assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count + Translation.count") do
      patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
      assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      assert_redirected_to hvid
    end

    evit.reload
    stime = evit.start_time
    assert_equal stime, evit_stime_2yr, "EventItem start time should not be updated this time because of other HaramiVid, but..."


    ## WARNING: This always accesses Google Youtube API.
    ## 6th and errorneous run (only if indicated so!)
    if is_env_set_positive?("SKIP_YOUTUBE_MARSHAL") # defined in ApplicationHelper
      hvid.update!(uri: hvid.uri+"naiyo")
      assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count") do
        assert_no_difference("Translation.count") do
          patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
          assert_response :unprocessable_entity
        end
      end

      flash_regex_assert(/\bURI\b.+\bwrong/i, msg=nil, type: :alert)
  
      sign_out @editor_harami
    end # if is_env_set_positive?("SKIP_YOUTUBE_MARSHAL")
  end

  private

    # @param hvid [HaramiVid]
    # @param ev_du_hr [Float]    Event#duration_hour       before PATCH
    # @param evit_du_min [Float] EventItem#duration_minute before PATCH
    # @param caller_msg [String] which caller?
    def _do_check_if_duration_adjusted(hvid, ev_du_hr, evit_du_min, caller_msg="Called from Default")
      assert(   (ev_du_hr2=hvid.events.first.duration_hour),        caller_msg)
      assert((evit_du_min2=hvid.event_items.first.duration_minute), caller_msg)
      assert_in_delta(ev_du_hr, ev_du_hr2, delta=0.00001, msg="(#{caller_msg}) inconsistent Duration")
      refute_equal    evit_du_min, evit_du_min2, "(#{caller_msg}: hvid-duration=#{hvid.duration.seconds.inspect}"
  
      ev_du_sec    = ev_du_hr*3600
      evit_du_sec2 = evit_du_min2*60
      assert_operator ev_du_sec, :>, hvid.duration*3, caller_msg
      assert_operator ev_du_sec, :>,  evit_du_sec2*3, caller_msg
      assert_operator evit_du_sec2, :>, hvid.duration*1.1, caller_msg
      assert_operator evit_du_sec2, :<, hvid.duration*2.1, "(#{caller_msg}) should be 1.5 times (ModuleHaramiVidEventAux::DEF_DURATION_RATIO_EVIT_TO_HVID), but..."
      evit_err_sec2 = hvid.event_items.first.duration_err_with_unit.in_seconds  # Duraion-ERR for EventItem in seconds
      assert_operator evit_err_sec2, :>, hvid.duration*0.5, caller_msg
      assert_operator evit_err_sec2, :<, hvid.duration*2.1, "(#{caller_msg}) should be 1.4 times (ModuleHaramiVidEventAux:: DEF_DURATION_ERR_RATIO_EVIT_TO_HVID), but..."
    end
end
