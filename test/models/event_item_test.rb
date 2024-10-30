# coding: utf-8
# == Schema Information
#
# Table name: event_items
#
#  id                                                                          :bigint           not null, primary key
#  duration_minute                                                             :float
#  duration_minute_err(in second)                                              :float
#  event_ratio(Event-covering ratio [0..1])                                    :float
#  machine_title                                                               :string           not null
#  note                                                                        :text
#  publish_date(First broadcast date, esp. when the recording date is unknown) :date
#  start_time                                                                  :datetime
#  start_time_err(in second)                                                   :float
#  weight                                                                      :float
#  created_at                                                                  :datetime         not null
#  updated_at                                                                  :datetime         not null
#  event_id                                                                    :bigint           not null
#  place_id                                                                    :bigint
#
# Indexes
#
#  index_event_items_on_duration_minute  (duration_minute)
#  index_event_items_on_event_id         (event_id)
#  index_event_items_on_event_ratio      (event_ratio)
#  index_event_items_on_machine_title    (machine_title) UNIQUE
#  index_event_items_on_place_id         (place_id)
#  index_event_items_on_start_time       (start_time)
#  index_event_items_on_weight           (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
require "test_helper"

class EventItemTest < ActiveSupport::TestCase
  # Test of unified handling of duration_error (in seconds at the time of writing despite its name of duration_minute_err)
  test "EventItem.num_with_unit_to_db_duration_err" do
    evit = event_items(:evit_1_harami_budokan2022_soiree)
    evit.update!(duration_minute_err: 240)
    assert          evit.duration_err_with_unit.respond_to?(:in_minutes)
    assert_equal 4, evit.duration_err_with_unit.in_minutes

    assert_equal 120, EventItem.num_with_unit_to_db_duration_err(2.minutes)
    assert_raises(NoMethodError){
      assert_equal 120, EventItem.num_with_unit_to_db_duration_err(2)}
  end

  test "constraints" do
    evit1 = event_items(:evit_1_harami_lucky2023)

    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo") }  # Validation failed: Event must exist
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
      EventItem.create!(machine_title: evit1.machine_title, event: evit1.event) } # DB-level Message: <"PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_event_items_on_machine_title\"\nDETAIL:  Key (machine_title)=(Lucky2023 No.1) already exists.\n">

    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo1", event: evit1.event, start_time_err: -3) }
    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo1", event: evit1.event, duration_minute: -3) }
    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo1", event: evit1.event, event_ratio: 1.5) }  # [0, 1] is allowed.
  end

  test "associations via ArtistMusicPlayTest" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")

    evit1 = event_items(:evit_1_harami_budokan2022_soiree)
    assert_operator 2, :<=, evit1.artist_music_plays.count, 'check has_many artist_music_plays and also fixtures'
    assert_operator 2, :<=, evit1.artists.count, 'check has_many artists and also fixtures'
    assert   evit1.artists.include?(artists(:artist_harami))
    assert_operator 1, :<=, evit1.musics.count, 'check has_many musics and also fixtures'
    assert_operator 2, :<=, evit1.play_roles.count, 'check has_many play_roles and also fixtures'
    assert_operator 2, :<=, evit1.instruments.count, 'check has_many instruments and also fixtures'

    assert_difference("ArtistMusicPlay.count", -ArtistMusicPlay.where(event_item: evit1).count, "Test of dependent"){
      evit1.destroy
    }
  end

  test "create_new_unknown!" do
    event = Event.new(event_group: EventGroup.last)
    ev_tit = "Events of create_new_unknown"
    event.unsaved_translations << Translation.new(title: ev_tit, langcode: "en", is_orig: nil)

    assert_raises(RuntimeError){
      evit = EventItem.create_new_unknown!(event)
    }

    event.save!
    unk_ev = event.unknown_event_item
    #print "NOTE: Automatically craeted unknown EventItem: #{unk_ev.inspect}"

    # The following should never be used in practice, because create_new_unknown! is an internal method called only by a callback in an Event creation.
    evit = nil
    assert_nothing_raised{
      evit = EventItem.create_new_unknown!(event)
    }
    assert evit.id
    refute_equal unk_ev.machine_title, evit.machine_title  # => "UnknownEventItem_1Events_of_create_new_unknown_..."
  end

  test "self.default" do
    evit = EventItem.default(context=nil, place: nil)
    assert_equal evit, EventItem.unknown

    pla = places(:tocho)
    evt = EventItem.default(:Harami1129, place: pla)
    assert_equal Event, evt.class
    assert   evt.new_record?
    #evt.save!

    assert_difference('Event.count + EventItem.count', 2) {
      evit = EventItem.default(:Harami1129, place: pla, save_event: true)
    }
    assert_equal EventItem, evit.class
    assert_equal evit.event.title(langcode: "en"), evt.unsaved_translations.find{|i| i.langcode = "en"}.title

    #evt.reload
    #evit = evt.event_items.first
    assert   evit.unknown?, "#{evit.inspect}"
    assert_equal pla, evit.place
    assert_match(/^UnknownEventItem_都庁.*でのイベント/, evit.machine_title) # See Event::UNKNOWN_TITLE_PREFIXES[:ja]
    evt1 = evt
    evit1 = evit

    pla2 = pla.unknown_sibling
    evt2 = EventItem.default(:Harami1129, place: pla2)
    assert_equal Event, evt2.class
    assert   evt2.new_record?
    evt2.save!
    evit = evt2.event_items.first
    assert_match(/^UnknownEventItem_Event_in/, evit.machine_title) # See Event::UNKNOWN_TITLE_PREFIXES[:en]

    pladiet = Place.create_basic!(prefecture_id: prefectures(:tokyo).id, title: "国会", langcode: "ja", is_orig: true)
    evit3 = EventItem.default(:Harami1129, place: pladiet, save_event: true)
    ev3 = evit3.event
    evgr3 = ev3.event_group
    evgr3_mods = %w(ja en).map{|i| [i, evgr3.title(langcode: i).gsub(/\s+/, "_")]}.to_h.with_indifferent_access
    assert ev3.title(langcode: "ja").include?(evgr3_mods[:ja])
    refute ev3.title(langcode: "en").include?(evgr3_mods[:en])
    refute evit3.machine_title.include?(evgr3_mods[:ja]), "evit3.machine_title=#{evit3.machine_title.inspect} should not include #{evgr3_mods[:ja].inspect}"
    assert evit3.machine_title.include?(evgr3_mods[:en])
  end

  test "self.new_default" do
    pref = Prefecture.create_basic!(title: (pref_tit='NewPrefectureJapan'), langcode: "en", country: Country["JPN"])
    pla  = Place.create_basic!(title: (pla_tit='NewPlaceJapan'), langcode: "en", prefecture: pref)

    evt0 = EventItem.new_default(:Harami1129, place: pla, save_event: false)
    assert_equal Event, evt0.class

    evit1 = EventItem.new_default(:Harami1129, place: pla, save_event: true)
    assert evit1.unknown?
    assert_equal evit1.event.title(langcode: "en"), evt0.unsaved_translations.find{|i| i.langcode = "en"}.title

    evit2 = EventItem.new_default(:Harami1129, place: pla, save_event: true)
    refute_equal evit1, evit2
    assert_equal evit1.place,      evit2.place
    assert_equal evit1.start_time, evit2.start_time

    evit3 = EventItem.new_default(:Harami1129, place: pla, save_event: true)
    assert_equal evit1.place,      evit3.place
    refute_equal evit1, evit3
    refute_equal evit2, evit3
    assert_operator 15, :<, evit3.machine_title.size, "machine_title=#{[evit1,evit2,evit3].map{|i| i.machine_title}.inspect}"  # "item1-Event_in_NewPlaceJapan(NewPrefectureJapan/Japan)_<_Single-shot_street_playing"
    assert_includes evit3.machine_title, "_<_"
    assert_includes evit3.machine_title, pref_tit
    assert_includes evit3.machine_title, pla_tit
    assert_match(/item.+#{Regexp.quote pla_tit}.*_<_./, evit3.machine_title)  # "item1-Event_in_NewPlaceJapan(NewPrefectureJapan/Japan)_<_Single-shot_street_playing"

    evit4 = EventItem.new_default(:Harami1129, place: (pla_jp_unk=Place.unknown(country: Country["JPN"])), save_event: true, ref_title: "[生配信]ある記念に", date: Date.today, place_confidence: :high)
    assert_equal EventGroup.find_by_mname(:live_streamings), evit4.event_group
    assert_equal Place[/ハラミ.+自宅/], (pla_home=Place.find_by_mname(:default_streaming)), 'sanity check'
    assert_equal pla_home,  Place[:default_streaming], 'sanity check'
    assert_equal pla_home,  evit4.place
  end

  test "unknown_sibling etc" do
    evit = EventItem.new_default(context=:Harami1129, place: places(:kawaramachi_station))
    evit2 = evit.dup
    evit2.update!(machine_title: "xyz-"+evit.machine_title+"-2")
    assert evit.unknown?
    assert_equal 2, evit2.event.event_items.count

    assert_equal 1, evit2.siblings.size, "siblings=#{evit.event.event_items.inspect}"
    assert          evit2.siblings.first.unknown?
    assert_equal 0, evit2.siblings(exclude_unknown: true).size
    assert (evit_unk=evit.unknown_sibling(force: false))
    evit_unk.update!(machine_title: 'dummy123')  # => unknown is not unknown any more.
    evit.reload
    evit2.reload
    assert_equal 2, evit2.event.event_items.count
    assert_nil          evit2.unknown_sibling(force: false)
    assert_equal 1, evit2.siblings.size
    assert_equal 1, evit2.siblings(exclude_unknown: true).size
    assert    (evit_unk=evit2.unknown_sibling(force: true))
    assert evit_unk.unknown?
    evit2.reload
    assert_equal 2, evit2.siblings.size
    assert_equal 1, evit2.siblings(exclude_unknown: true).size
  end

  test "default_unique_title" do
    evit = event_items(:evit_ev_evgr_unknown)
    assert_equal "item-UnknownEvent-UncategorizedEventGroup",  (ut=evit.default_unique_title)
    EventItem.create!(machine_title: ut, event: evit.event)
    assert_equal "item1-UnknownEvent-UncategorizedEventGroup", (ut=evit.default_unique_title)

    evgr_tit = "NaiyoEvgr"
    evgr = EventGroup.create_basic!(title: evgr_tit, langcode: "en")
    evgr.reload
    ev_tit = evgr.events.first.title(langcode: "en")
    # assert_match(/#{evgr_tit}\Z/, ev_tit)
    evit = evgr.event_items.first
    assert_includes evit.machine_title, ev_tit.gsub(/\s+/, "_")
    assert_includes evit.machine_title, evgr_tit
    refute_includes evit.machine_title.sub(/#{evgr_tit.gsub(/\s+/, "_")}/, ""), evgr_tit, evit.machine_title.inspect

    pla = places(:perth_aus)
    ev2 = Event.default(:HaramiVid, place: pla)
    ev2.save!
    ev2.reload
    evgr_tit = ev2.event_group.title(langcode: "en")
    ev_tit = ev2.title(langcode: "en")
    assert_match(/#{evgr_tit}\Z/, ev_tit)
    evit = ev2.event_items.first
    assert_includes evit.machine_title, ev_tit.gsub(/\s+/, "_")
    assert_includes evit.machine_title, evgr_tit.gsub(/\s+/, "_")
    refute_includes evit.machine_title.sub(/#{evgr_tit.gsub(/\s+/, "_")}/, ""), evgr_tit.gsub(/\s+/, "_"), "machine_title=#{evit.machine_title.inspect}"  # EventGroup should not be doubly included in machine_title of EventItem.
  end

  test "open_ended?" do
    evit = EventItem.new_default(context=:Harami1129, place: places(:kawaramachi_station))
    assert_nil evit.duration_minute , 'sanity check of fixture'
    assert evit.open_ended?

    evit.update!(duration_minute: 60*24*365*200)  # 200 years
    assert evit.open_ended?
    evit.update!(duration_minute: 60*24*365*10)   # 10 years
    refute evit.open_ended?
  end

  test "association" do
    assert_nothing_raised{ EventItem.first.harami_vids }
  end
end
