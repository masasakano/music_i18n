# coding: utf-8
# == Schema Information
#
# Table name: harami_vids
#
#  id                                                                                     :bigint           not null, primary key
#  duration(Total duration in seconds)                                                    :float
#  flag_by_harami(True if published/owned by Harami)                                      :boolean
#  note                                                                                   :text
#  release_date(Published date of the video)                                              :date
#  uri((YouTube) URI of the video)                                                        :text
#  uri_playlist_en(URI option part for the YouTube comment of the music list in English)  :string
#  uri_playlist_ja(URI option part for the YouTube comment of the music list in Japanese) :string
#  created_at                                                                             :datetime         not null
#  updated_at                                                                             :datetime         not null
#  channel_id                                                                             :bigint
#  place_id(The main place where the video was set in)                                    :bigint
#
# Indexes
#
#  index_harami_vids_on_channel_id    (channel_id)
#  index_harami_vids_on_place_id      (place_id)
#  index_harami_vids_on_release_date  (release_date)
#  index_harami_vids_on_uri           (uri) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (channel_id => channels.id)
#  fk_rails_...  (place_id => places.id)
#
require 'test_helper'

class HaramiVidTest < ActiveSupport::TestCase
  test "constraints" do
    pf1 = Place.first
    uri1 = 'http://youtu.be/abcd'
    assert_nothing_raised{
      hv0 = HaramiVid.create!(place: pf1, uri: "https://a.com/b")
    }
    hv1 = HaramiVid.create!(uri: uri1, place: pf1)
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ # "Validation failed: Uri has already been taken"
      p HaramiVid.create!(uri: uri1, place: pf1)
    }
    
    hv1.with_translation(title: 'my title', langcode: 'en')

    uri2 = 'http://youtu.be/uri2'
    assert_nothing_raised{
      hv2 = HaramiVid.create!(uri: uri2)
      assert hv2.place
    }
  end

  test "callbacks" do
    identifier = "BBBCCCCQxU4"
    hv = HaramiVid.new(uri: "https://www.youtube.com/watch?v="+identifier, title: "naiyo", langcode: "en", channel: Channel.unknown)
    hv.save!
    assert_equal "youtu.be/"+identifier, hv.uri
    hv2 = hv.dup
    refute hv2.valid?
    hv2.uri = "https://youtu.be/shorts/"+identifier
    refute hv2.valid?
    hv2.uri = "https://youtube.com/live/watch?v="+identifier
    refute hv2.valid?
    hv2.uri = "youtu.be/xxxxnaiyo"
    assert hv2.valid?
    hv2.unsaved_translations << Translation.new(title: "naiyo", langcode: "en")  # The same title should be allowed.
    hv2.save!
  end

  test "find_one_for_harami1129 for existing record" do
    [:harami1129_ai, :harami1129_ihojin1].each do |ea_key|
      h1129 = harami1129s(ea_key)
      # music = musics(:music_story)
      # artist_ai = artists(:artist_ai)

      hvid = HaramiVid.find_one_for_harami1129(h1129)
      case ea_key
      #when :harami1129_ai
      #  refute     hvid.event_items.exists?  # HaramiVid Fixture includes no EventItem
      when :harami1129_ihojin1, :harami1129_ai
        assert     hvid.event_items.exists?  # HaramiVid Fixture includes EventItem
        assert_includes hvid.event_items, h1129.event_item if :harami1129_ihojin1 == ea_key  # according to Fixture
      else
        raise
      end
 
      assert_not hvid.new_record?
      assert_not hvid.changed?

      hvid.set_with_harami1129(h1129, updates: %i(ins_link_root ins_title ins_release_date))
      case ea_key
      when :harami1129_ai
        assert     hvid.changed?
        assert     hvid.release_date_changed?
        assert_nil hvid.release_date_was
        refute_equal h1129.ins_title, hvid.best_translations.first[1].title  # Hash#first => 2-element Array
        #refute     hvid.event_items.exists?  # Because Harami1129's record does not include it.
      when :harami1129_ihojin1
        refute     hvid.changed?
        refute     hvid.release_date_changed?
        assert     hvid.release_date_was
        assert_equal h1129.ins_title, hvid.best_translations.first[1].title
        assert_includes hvid.event_items, h1129.event_item  # HaramiVid#event_items includes Harami1129's EventItem
      else
        raise
      end
      assert_not   hvid.uri_changed?
      assert_equal h1129.ins_release_date, hvid.release_date
    end
  end

  test "find_one_for_harami1129 for new record" do
    h1129 = harami1129s(:harami1129_rcsuccession)

    harami_vid = HaramiVid.find_one_for_harami1129(h1129)
    assert     harami_vid.new_record?
    assert_not harami_vid.changed?

    # 1st try
    assert_raises(MultiTranslationError::InsufficientInformationError){
      harami_vid.set_with_harami1129(h1129, updates: %i(ins_title ins_release_date)) } #  HaramiVid is a new record, yet :ins_link_root is not specified. Contact the code developer.

    # 2nd try
    harami_vid.set_with_harami1129(h1129, updates: %i(ins_link_root))
    assert     harami_vid.new_record?
    assert     harami_vid.changed?
    assert_not harami_vid.release_date_changed?
    assert_nil harami_vid.release_date_was
    assert     harami_vid.uri_changed?
    assert_not_equal h1129.ins_release_date, harami_vid.release_date
    assert     harami_vid.best_translations.empty?  # No Translation associated, yet.
    assert     harami_vid.unsaved_translations.blank?    # No unsaved because it is not specified in "updates"

    # 3rd try
    harami_vid.set_with_harami1129(h1129, updates: %i(ins_link_root ins_title ins_release_date))
    assert     harami_vid.new_record?
    assert     harami_vid.changed?
    assert     harami_vid.release_date_changed?
    assert_nil harami_vid.release_date_was
    assert     harami_vid.uri_changed?
    assert_equal h1129.ins_release_date, harami_vid.release_date
    assert     harami_vid.translations.empty?  # No Translation associated, yet.
    assert_equal h1129.ins_title, harami_vid.unsaved_translations.first.title # but an unsaved one.
    # :harami1129_ewf
    #:artist_rcsuccession
    #:artist_rcsuccession_ja
  end

  test "set_event_item_if_live_streaming" do
    hvid = HaramiVid.create_basic!(title: (tit_orig='生配信するよ'), langcode: "ja", is_orig: true, uri: "youtu.be/abcdefghi", release_date: (dat_hvid=Date.new(2024,3,5)), channel: Channel.default(:HaramiVid))
    hvid.musics << (mu1=musics(:music1))
    hvid.musics << (mu2=musics(:music2))
    assert          hvid.event_items.empty?, 'sanity check'
    assert_equal 2, hvid.musics.count, 'sanity check'

    # NOT live-streaming HaramiVid
    assert_no_difference('ArtistMusicPlay.count'){
      assert_no_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count'){
        harami_vids(:harami_vid1).set_event_item_if_live_streaming(create_amps: true)
      }
    }

    # For live-streaming HaramiVid
    assert_difference('HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count', 2){
      assert_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count', 3){
        assert_equal EventItem, hvid.set_event_item_if_live_streaming(create_amps: true).class
      }
    }

    assert_equal 1, hvid.event_items.size
    evit = hvid.event_items.first
    assert_equal EventGroup.find_by_mname(:live_streamings), evit.event_group
    assert_includes evit.event.title(langcode: "ja"), tit_orig
    assert_equal dat_hvid, evit.event.start_time.to_date

    assert_equal 2, evit.musics.count
    assert_equal 2, evit.artist_music_plays.count
    assert_includes evit.musics, mu1
    assert_includes evit.musics, mu2

    # 2nd-time run
    assert_no_difference('ArtistMusicPlay.count'){
      assert_no_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count'){
        assert_nil hvid.set_event_item_if_live_streaming(create_amps: true)
      }
    }

    hvid = HaramiVid.create_basic!(title: (tit_orig='同じ日の別の生配信'), langcode: "ja", is_orig: true, uri: "youtu.be/abcdefghi2", release_date: dat_hvid, channel: Channel.default(:HaramiVid))
    existing_evt = Event.create_basic!(title: "tmp-event1", langcode: "en", is_orig: true, event_group: EventGroup.default(:HaramiVid))
    existing_evit = existing_evt.unknown_event_item
    existing_amp = ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item: existing_evit, music: musics(:music1))
    existing_amp.save!
    existing_evit.artist_music_plays.reset
    hvid.event_items << existing_evit
    hvid.reload  # to refresh all associations
    # HaramiVid associated with an EventItem with an ArtistMusicPlay (but not with Music via HaramiVidMusicAssoc)

    h1129_1 = harami1129s(:harami1129one)
    h1129_1.update!(harami_vid: hvid, event_item: existing_evit)
    h1129_2 = harami1129s(:harami1129two)
    h1129_2.update!(harami_vid: hvid, event_item: existing_evit)

    # Always new Event is created for live-streaming. Existing ArtistMusicPlay is copied regardless of create_amps
    assert_difference('HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count', 1){
      assert_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count', 3){
        assert_equal EventItem, hvid.set_event_item_if_live_streaming(create_amps: false).class
      }
    }

    evgr_streaming = EventGroup.find_by_mname(:live_streamings)

    assert_equal 2, hvid.event_items.size, "should be 2 = existing(StreetPiano) + new(Streaming), but..."
    assert_includes hvid.event_items, existing_evit
    evit = hvid.event_items.last
    refute_equal existing_evit, evit, 'sanity check'
    assert_equal evgr_streaming, evit.event_group
    assert_includes evit.event.title(langcode: "ja"), tit_orig

    assert_equal 2, hvid.artist_music_plays.size, "should be 2 = existing(StreetPiano) + new(Streaming), but..."
    assert_equal 1, evit.musics.count
    assert_equal 1, evit.artist_music_plays.count
    assert_equal existing_amp.music, evit.artist_music_plays.first.music

    assert_equal evit, h1129_1.reload.event_item
    assert_equal evit, h1129_2.reload.event_item

    # run with HaramiVid with multiple existing (non-live-streaming) EventItem-s
    hvid = harami_vids(:harami_vid_ihojin1)
    assert hvid.event_items.exists?, 'sanity check'
    assert_operator 1, :<, hvid.event_items.count, 'sanity check'
    assert_equal event_items(:evit_1_harami_lucky2023), (evit=hvid.event_items.first), 'test fixtures'  # prone to future changes
    refute_equal evgr_streaming, evit.event_group, 'test fixtures'
    assert_no_difference('HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count'){
      assert_no_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count'){
        assert_nil hvid.set_event_item_if_live_streaming(create_amps: true)
      }
    }

    # run with HaramiVid with an existing (non-live-streaming) EventItem; there is no default Event for the Place
    hvid = harami_vids(:three)
    assert hvid.event_items.exists?, 'sanity check'
    assert_equal 1, hvid.event_items.count, 'sanity check'
    assert_equal event_items(:three), (evit=hvid.event_items.first), 'test fixtures'  # prone to future changes
    refute_equal evgr_streaming, evit.event_group, 'test fixtures'
    assert_no_difference('HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count'){
      assert_no_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count'){
        assert_nil hvid.set_event_item_if_live_streaming(create_amps: true)
      }
    }

    # run with HaramiVid with an existing EventItem; an Event for the Place (unknown Prefecture in Japan) exists.
    hvid = harami_vids(:four)
    assert hvid.event_items.exists?, 'sanity check'
    assert_equal 1, hvid.event_items.count, 'sanity check'
    exp = event_items(:evit_ev_evgr_single_streets_unknown_japan_unknown)
    assert_equal exp, (evit=hvid.event_items.first), 'test fixtures'  # prone to future changes
    refute_equal evgr_streaming, evit.event_group, 'test fixtures'

    assert_no_difference('HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count'){
      assert_no_difference('Event.count + EventItem.count + HaramiVidEventItemAssoc.count'){
        assert_nil hvid.set_event_item_if_live_streaming(create_amps: true)
      }
    }
  end

  test "create_basic!" do
    mdl = nil
    assert_nothing_raised{
      mdl = HaramiVid.create_basic!}
    assert_match(/^HaramiVid\-basic\-/, mdl.title)
  end

  test "association" do
    model = HaramiVid.first
    assert_nothing_raised{ model.channel }
    assert_nothing_raised{ model.channel_owner }
    assert_nothing_raised{ model.channel_type }
    assert_nothing_raised{ model.channel_platform }
    assert_nothing_raised{ model.event_items }
    assert_nothing_raised{ model.events }
    assert_nothing_raised{ model.event_groups }
    assert_nothing_raised{ model.artist_collabs }

    hv = harami_vids(:harami_vid_ihojin1)
    evis = [event_items(:one), event_items(:evit_1_harami_lucky2023), event_items(:evit_2_harami_lucky2023)]
    assert_equal 2, evis[1].artists.size, "#{evis[1].artists.inspect}; confirms fixtures"
    assert_equal 2, evis[2].artists.size, '#{evis[2].artists.inspect}; confirms fixtures'
    assert_equal evis, hv.event_items.order("event_items.start_time").to_a
    assert_equal EventItem, hv.event_items[1].class, "#{hv.event_items.first.inspect}"
    assert hv.artist_music_plays.exists?
    assert_equal Artist, hv.artist_collabs[1].class, "#{hv.artist_music_plays.first.inspect}"
  end
end
