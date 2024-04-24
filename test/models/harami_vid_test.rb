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
      hv0 = HaramiVid.create!(place: pf1)
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

  test "find_one_for_harami1129 for existing record" do
    h1129 = harami1129s(:harami1129_ai)
    # music = musics(:music_story)
    # artist_ai = artists(:artist_ai)

    harami_vid = HaramiVid.find_one_for_harami1129(h1129)

    assert_not harami_vid.new_record?
    assert_not harami_vid.changed?

    harami_vid.set_with_harami1129(h1129, updates: %i(ins_link_root ins_title ins_release_date))
    assert     harami_vid.changed?
    assert     harami_vid.release_date_changed?
    assert_nil harami_vid.release_date_was
    assert_not harami_vid.uri_changed?
    assert_equal h1129.ins_release_date, harami_vid.release_date
    assert_not_equal h1129.ins_title, harami_vid.best_translations.first[1].title  # Hash#first => 2-element Array
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
    assert     harami_vid.best_translations.empty?  # No Translation associated, yet.
    assert_equal h1129.ins_title, harami_vid.unsaved_translations.first.title # but an unsaved one.
    # :harami1129_ewf
    #:artist_rcsuccession
    #:artist_rcsuccession_ja
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
    evis = [event_items(:evit_1_harami_lucky2023), event_items(:evit_2_harami_lucky2023)]
    assert_equal 1, evis[0].artists.size, 'confirms fixtures'
    assert_equal 2, evis[1].artists.size, 'confirms fixtures'
    assert_equal evis, hv.event_items.order("event_items.start_time").to_a
    assert_equal EventItem, hv.event_items.first.class, "#{hv.event_items.first.inspect}"
    assert hv.artist_music_plays.exists?
    assert_equal Artist, hv.artist_collabs.first.class, "#{hv.artist_music_plays.first.inspect}"
  end
end
