# coding: utf-8
require "test_helper"

class EventItems::DestroyWithAmpsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @event_item = event_items(:one)
    #@sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    #@moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    #@moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should destroy event_item and ArtistMusicPlays" do
    #### preparing test-data and sanity checks
    _prepare_models(Event.default(:HaramiVid))
    assert_operator 1, :<, @evit.event.event_items.count, "There should be another EventItem in the Event, but..."
    assert_equal 2, @hvid.event_items.count, 'sanity check...'  # it is essential HaramiVid has multiple EventItems (you could not destroy the last EventItem)
    assert_equal 4, @hvid.artist_music_plays.count, 'sanity check...'  # see "set_event_item_if_live_streaming" in /test/models/harami_vid_test.rb for why the size is doubled.
    assert_equal 2, @evit.artist_music_plays.count, 'there should be no change - sanity check...'

    assert @existing_amp1.sames_but(event_item: @evit).exists?, "practically, model-test of ArtistMusicPlay#sames_but (providing HaramiVid#.set_event_item_if_live_streaming is working)"
    assert @evit.associated_amps_all_duplicated?, "practically, model-test of EventItem#associated_amps_all_duplicated? (providing HaramiVid#.set_event_item_if_live_streaming is working)"

    #### attempts by unauthorized users

    delete play_role_url(@evit)
    get new_harami_vid_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@trans_moderator, @editor_harami].each do |user|
      sign_in user
      _should_reject_in_ability(evit=@evit, user: user)
      sign_out user
    end

    ### Failed due to another existing HaramiVid (even submitted by an admin)

    hvid_other = harami_vids(:one)
    hvid_other.event_items << @evit
    @evit.harami_vids.reset
    assert_equal 2, @evit.harami_vids.count, 'sanity check'

    sign_in @syshelper
    _should_reject_in_ability(evit=@evit, user: @moderator_harami)
    sign_out @syshelper

    ### Failed due to EventItem having a unique ArtistMusicPlay (all ArtistMusicPlay-s must be duplicated before this call)

    amp2_2 = @existing_amp2.sames_but(event_item: @evit).first
    amp2_2_dup = amp2_2.dup
    amp2_2.destroy!
    @evit.artist_music_plays.reset
    refute @evit.associated_amps_all_duplicated?, @existing_amp2.sames_but(event_item: @evit).inspect #'sanity check'

    sign_in @syshelper
    _should_reject_in_ability(evit=@evit, user: @moderator_harami)
    sign_out @syshelper

    amp2_2_dup.save!  # recovers the ArtistMusicPlay
    @evit.artist_music_plays.reset
    assert @evit.associated_amps_all_duplicated?, 'sanity check'

    ### should succeed

    hvid_other.event_items.destroy @evit
    @evit.harami_vids.reset
    assert_equal 1, @evit.harami_vids.count, 'sanity check'

    sign_in @moderator_harami

    get harami_vid_path(@hvid)
    assert_response :success

    assert_difference("Harami1129.count*100 + HaramiVid.count*10 + Engage.count", 0) do
      assert_difference("Event.count*1000 + EventItem.count*100 + HaramiVidEventItemAssoc.count*10 + ArtistMusicPlay.count", -112) do
        delete event_items_destroy_with_amp_url(@evit)
        assert_response :redirect
      end
    end
    #assert_redirected_to harami_vid_path(@hvid), "should be redirected back"  # but I don't know how to do so in Controller tests...
    assert_redirected_to harami_vids_path, "fallback in redirect back"

    @hvid.reload
    assert_equal 1, @hvid.event_items.count

    [@existing_amp1, @existing_amp2].each do |amp|
      refute ArtistMusicPlay.exists?(id: amp.id)
    end

    refute EventItem.exists?(id: @evit.id)

    sign_out @moderator_harami
  end


  test "should destroy Event and event_item and ArtistMusicPlays" do
    #### preparing test-data and sanity checks
    evt = Event.create_basic!(title: "test Event7", langcode: "en", is_orig: true, event_group: EventGroup.default(:HaramiVid))  # n.b., this EvnetGroup should NOT be :live-streamings (because of how the rest of data are parepared)
    assert_operator 1, :<, evt.event_group.events.count, "sanity check; necessary to allow destroying the Event"
    _prepare_models(evt)
    assert_equal evt, @evit.event, 'sanity check'
    assert_equal 2, @evit.event.event_items.count, "There should be only 2 EventItems (unknown and new default) in the Event, but..."
    assert_equal 2, @hvid.event_items.count, 'sanity check...'  # it is essential HaramiVid has multiple EventItems (you could not destroy the last EventItem)
    assert_equal 4, @hvid.artist_music_plays.count, 'sanity check...'  # see "set_event_item_if_live_streaming" in /test/models/harami_vid_test.rb for why the size is doubled.
    assert_equal 2, @evit.artist_music_plays.count, 'there should be no change - sanity check...'

    sign_in @moderator_harami
    assert_difference("Harami1129.count*100 + HaramiVid.count*10 + Engage.count", 0) do
      assert_difference("Event.count*1000 + EventItem.count*100 + HaramiVidEventItemAssoc.count*10 + ArtistMusicPlay.count", -1212) do
        delete event_items_destroy_with_amp_url(@evit)
        assert_response :redirect
      end
    end
    #assert_redirected_to harami_vid_path(@hvid), "should be redirected back"  # but I don't know how to do so in Controller tests...
    assert_redirected_to harami_vids_path, "fallback in redirect back"

    @hvid.reload
    assert_equal 1, @hvid.event_items.count

    [@existing_amp1, @existing_amp2].each do |amp|
      refute ArtistMusicPlay.exists?(id: amp.id)
    end

    refute EventItem.exists?(id: @evit.id)
    refute Event.exists?(id: evt.id)
    sign_out @moderator_harami
  end

  private

    def _prepare_models(event)
      @evit = EventItem.new_default(:HaramiVid, event: event)
      assert_operator 1, :<, @evit.event.event_items.count, "There should be another EventItem in the Event, but..."
      @hvid = HaramiVid.create_basic!(title: "生配信だよん", langcode: "ja", is_orig: "true", uri: "youtu.be/abcde1", release_date: (dat=Date.current-3), channel: Channel.default(:HaramiVid), place: Place.find_by_mname(:default_harami_vid))
      @hvid.musics << (@mus1=musics(:music1))
      @hvid.event_items << @evit

      @existing_amp1 = ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item: @evit, music: @mus1)
      @existing_amp1.save!
      @existing_amp2 = @existing_amp1.dup
      @existing_amp2.instrument = instruments(:instrument_organ)
      @existing_amp2.save!
      @hvid.reload  # to refresh all associations
      # HaramiVid associated with 1 HaramiVidMusicAssoc and an EventItem with 2 ArtistMusicPlays for the same Music (with different Instrument-s)
      @evit.reload

      assert_equal 2, @hvid.artist_music_plays.count, 'sanity check...'
      assert_equal 2, @evit.artist_music_plays.count, 'sanity check...'
      refute @evit.harami1129s.exists?

      # Always new Event is created for live-streaming. Existing ArtistMusicPlay is copied regardless of create_amps
      assert_difference('HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count', 2){
        assert_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count', 3){
          @hvid.set_event_item_if_live_streaming(create_amps: false)
        }
      }

      @hvid.reload
      @evit.reload
      @evit_other = @hvid.event_items.last
    end

    def _should_reject_in_ability(evit=@evit, user: nil)
      assert_no_difference("Harami1129.count*100 + HaramiVid.count*10 + Engage.count") do
        assert_no_difference("Event.count*1000 + EventItem.count*100 + HaramiVidEventItemAssoc.count*10 + ArtistMusicPlay.count") do
          delete event_items_destroy_with_amp_url(evit)
          assert_response :redirect
        end
      end
      assert_redirected_to root_path, "Failure in deletion by #{user && user.display_name || 'unknown'} leads to Root-path"
    end
end
