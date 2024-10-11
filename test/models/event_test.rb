# coding: utf-8
# == Schema Information
#
# Table name: events
#
#  id                        :bigint           not null, primary key
#  duration_hour             :float
#  note                      :text
#  start_time                :datetime
#  start_time_err(in second) :bigint
#  weight                    :float
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  event_group_id            :bigint           not null
#  place_id                  :bigint
#
# Indexes
#
#  index_events_on_duration_hour   (duration_hour)
#  index_events_on_event_group_id  (event_group_id)
#  index_events_on_place_id        (place_id)
#  index_events_on_start_time      (start_time)
#  index_events_on_weight          (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_group_id => event_groups.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "consistency on fixtures and translations" do
    Event.all.each do |model|
      assert model.translations.exists?, "No translation is found for Event=#{model.inspect}"
    end
  end

  test "create_basic! and trans" do
    evgr = EventGroup.third
    ev = Event.create_basic!(title: "ANew Evt", langcode: "en", event_group: evgr)
    ev.reload
    assert_equal 1, ev.translations.size, "#{ev.translations.to_a}"
    assert_equal "ANew Evt", ev.best_translation.title
  end

  test "on delete" do
    evt = events(:ev_harami_lucky2023)

    assert_raises(ActiveRecord::RecordInvalid){ evt.update!(duration_hour: -8) }
    evt.reload # must exist

    assert_equal 2023, evt.start_time.year, "sanity check: time=#{evt.start_time.inspect}"
    assert_equal evt.event_group.start_date, evt.start_time.to_date, "parent's date"

    pla = evt.place
    assert pla
    refute pla.prefecture.unknown?

    pla.destroy
    evt.reload
    assert_nil evt.place, "Though it should be changed into a different value when Place is destroyed, it has to be technically allowed to be nullified."

    # destroy with Dependency
    refute evt.destroyable?
    assert_raises(ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){  # Rails level (has_many - dependent) and DB-level, respectively
      evt.destroy! }
    assert_raises(ActiveRecord::DeleteRestrictionError) {
      evt.event_items.each do |ei|
        ei.destroy
      end }  # => Cannot delete record because of dependent harami_vid_event_item_assocs
    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) {
      evt.harami_vids.destroy_all }
    evt.event_items.each do |ei|
      ei.harami_vids.destroy_all  # Although the error is for the association"dependent harami_vid_event_item_assocs", the underlying key policy is that you should not destroy EventItem without destroing the dependent HaramiVid(s) first.
      if ei.harami1129s.exists?
        assert_raises(ActiveRecord::DeleteRestrictionError) { ei.destroy }
        ei.harami1129s.each do |eh|
          eh.update! event_item: nil
        end
        ei.reload # Essential.
      end
      ei.destroy
    end
    evt.event_items.each do |ei|
      ei.destroy  # this time it should be ok.  You can do it instead with:  evt.event_items.destroy_all
    end
    evt.reload  # Essential (because of caching).
    evt.destroy
    refute Event.exists?(evt.id)
  end

  test "in creating" do
    evt_base = events(:ev_harami_lucky2023)

    evt = Event.new(start_time: Time.new(2024,2,3,11,0, in: "+09:00"), duration_hour: 5, event_group: evt_base.event_group, place: evt_base.place) 

    ## Testing unique-translation violation.
    tra_base = evt_base.best_translation
    tra1 = tra_base.dup
    tra1.translatable_id = nil
    tra1.translatable_type = nil
    tra1.weight = 23.9
    evt.unsaved_translations << tra1

    assert_raises(ActiveRecord::RecordInvalid){ evt.save! }  # title="HARAMIchan at LuckyFes 2023" (en) already exists in Translation for Event in Class ("LuckyFes 2023").

    new_tit = "New test title 98"
    evt.unsaved_translations.first.title = new_tit
    assert_nothing_raised{ evt.save! }  # OK for a different title

    evt.reload
    assert_equal new_tit, evt.title

    # Translation#update! would fail.
    tra_new = evt.best_translation
    assert_raises(ActiveRecord::RecordInvalid){ tra_new.update!(title: tra_base.title) } # RuntimeError: Neutered Exception ActiveRecord::RecordInvalid: Validation failed: title="HARAMIchan at LuckyFes 2023" (en) already exists in Translation for Event in Class ("LuckyFes 2023").

    # For those belonging to different EventGroup-s, the same title is fine.
    evt.update!(event_group: EventGroup.unknown)
    assert_nothing_raised{                      tra_new.update!(title: tra_base.title) }
  end

  test "ApplicationRecord.allow_destroy_all" do
    evt = Event.create_basic!
    assert_equal 1, evt.event_items.count
    assert_difference('EventItem.count', 0, "Sole unknown EventItem should not be destroyed in default, but..."){
      assert_raise(ActiveRecord::RecordNotDestroyed){
        evt.event_items.destroy_all } }

    refute ApplicationRecord.allow_destroy_all, "sanity check of the default App..."
    begin
      ApplicationRecord.allow_destroy_all=true  # now allowing destroy
      assert_difference('EventItem.count', -1){
        evt.event_items.destroy_all }
    ensure
      ApplicationRecord.allow_destroy_all=false
    end
  end

  test "unknown_event_item" do
    evt_base = events(:ev_harami_lucky2023)
    evit_def = event_items(:evit_ev_harami_lucky2023_unknown)
    assert_equal evt_base, evit_def.event, 'test fixtures'
    assert evit_def.unknown?, 'test fixtures'
    assert_equal evit_def, evt_base.unknown_event_item(force: false), 'sanity check'

    evit_def.delete
    assert evit_def.destroyed?
    assert_nil evt_base.unknown_event_item(force: false)
    assert     (evit_new=evt_base.unknown_event_item(force: true))
    assert  evit_new.unknown?
    evt_base.reload
    assert_equal evit_new, evt_base.unknown_event_item(force: false)

    evit_new.delete
    assert     (evit_new2=evt_base.unknown_event_item)  # Default behaviour (from June 2024, after 1 commit after 7138ab5)
    assert  evit_new2.unknown?
  end

  test "self.default" do
    evt = Event.default(context=nil, place: nil)
    exp = Event.unknown
    assert_equal exp, evt 
    assert evt.default?

    evt = Event.default(context=:Harami1129)
    exp = event_groups(:evgr_single_streets)
    assert_equal exp, evt.event_group
    assert  evt.unknown?
    assert evt.default?
    evt_unknown = evt

    evt = Event.default(:Harami1129, place: Place.unknown)
    refute  evt.unknown?
    refute_equal evt_unknown, evt
    assert_equal evt_unknown.event_group, evt.event_group
    assert_match(/^どこかの場所\(どこかの都道府県\/世界\)で?の.+ストリート/, evt.title(langcode: :ja), "Event=#{evt.inspect}")
    assert_raises(RuntimeError) {
      evt.default? }  # invalid method (default?) for a new record.
    evt.save!
    assert evt.default?
    evt_world = evt

    evt = Event.default(:Harami1129, place: Place.unknown(country: Country['JPN']), save_event: true)
    refute_equal evt_world, evt
    assert_equal evt_world.event_group, evt.event_group
    refute_equal evt_world.place,       evt.place
    assert evt.place.unknown?
    assert_match(/^どこかの場所\(どこかの都道府県\/日本\)で?の.+ストリート/, evt.title(langcode: :ja), "Event=#{evt.inspect}")
    assert evt.default?
    evt_japan = evt
    evt_japan.save!

    pla = places(:perth_aus)
    evt_prev = Event.last
    evt = nil
    assert_nil Event.find_by(place: pla), 'sanity check'
    assert_no_difference('Event.count') do
      evt = Event.default(:Harami1129, place: pla)
    end
    assert_difference('Event.count') do
      assert evt.save
    end
    assert_equal pla, evt.place
    refute_equal evt_prev, evt
    assert evt.default?

    evgr_uk2024 = event_groups(:evgr_uk2024)
    pref_london = prefectures(:greater_london)
    evt = Event.default(:Harami1129, save_event: true, ref_title: "ロンドンのパブで演奏してみた", date: Date.new(2024,3,25))
    assert_equal evgr_uk2024, evt.event_group
    assert  pref_london.encompass?(evt.place), "place=#{evt.place.inspect}"
    assert_equal 2024,      evt.start_time.year
    assert_equal 3,         evt.start_time.month
    assert_operator 20, :>, evt.start_time.day
    assert_operator  5, :<, evt.start_time_err.seconds.in_days

    kings_cross = Place.create_basic!(title: "Kings Cross Station", langcode: "en", is_orig: true, prefecture: pref_london)
    assert  pref_london.encompass?(evt.place), 'sanity check'
    assert_difference('Event.count') do  # New place means a new Event
      evt = Event.default(:Harami1129, place: kings_cross, save_event: true, ref_title: "外国の駅で")
    end
    assert evt.default?
    assert_equal evgr_uk2024, evt.event_group
    assert_equal kings_cross, evt.place
    assert_equal kings_cross, evt.event_items.first.place

    assert_difference('Event.count') do
      evt = Event.default(:Harami1129, save_event: true, ref_title: "6月の生配信", date: Date.new(2024, 5, 6))
    end
    evgr_streaming = event_groups(:evgr_live_streamings)
    assert_equal evgr_streaming, evt.event_group
    assert evt.default?
    assert_equal 2024,      evt.start_time.year
    assert_equal 5,         evt.start_time.month
    assert_equal 6,         evt.start_time.day
    assert_operator  8, :>, evt.start_time_err.seconds.in_days
    pla_home=Place.find_by_mname(:default_streaming)
    assert_equal pla_home,  evt.place
  end

  test "self.default 2" do
    evt = Event.default(:Harami1129, place: Place.unknown(country: Country['JPN']))
    evt_japan = evt
    evt_japan.save!

    evt = Event.default(:Harami1129, place: Place.unknown(country: Country['JPN']))
    assert_equal evt_japan, evt, "#{[evt_japan, evt].inspect}"

    evt = Event.default(:Harami1129, place: places(:unknown_place_tokyo_japan))
    refute_equal evt_japan, evt, "#{[evt_japan, evt].inspect}"
    assert_match(/^UnknownPlace\(東京.+で?の.+ストリート/, evt.title(langcode: :ja))
      # Note that this "UnknownPlace" should usually never happen.  However, the fixture for Translation
      # does not exist and that is why. This is a good test for language fallback (where the requested
      # language is not defined for a Place, which can often happen).
    evt_tokyo = evt
    evt_tokyo.save!

    pla = places(:tocho)
    evt = Event.default(:Harami1129, place: pla)
    refute_equal evt_tokyo, evt
    assert evt.save, "Event=#{evt}"
  end

  test "self.def_time_parameters" do
    eg = EventGroup.create_basic!(start_date: Date.new(2005, 8, 15))
    hsret = Event.def_time_parameters(eg)
    assert_equal eg.start_date.year, hsret[:start_time].year
    assert_equal eg.start_date.day,  hsret[:start_time].day
    assert_equal 12,                 hsret[:start_time].utc.hour, "start_time input = #{hsret[:start_time].inspect}"
  end

  test "open_ended?" do
    evt = Event.default(context=:Harami1129, place: places(:kawaramachi_station))
    assert_nil evt.duration_hour , 'sanity check of fixture'
    assert evt.open_ended?

    evt.update!(duration_hour: 24*365*200)  # 200 years
    assert evt.open_ended?
    evt.update!(duration_hour: 24*365*10)   # 10 years
    refute evt.open_ended?

    assert events(:ev_evgr_single_streets_unknown_japan).open_ended?
  end

  test "association" do
    event = Event.first
    assert_nothing_raised{ event.event_items }
    assert_nothing_raised{ event.harami_vids }
  end

  test "callbacks" do
    assert  Event.unknown.event_group.unknown?

    evt1 = evt2 = nil
    assert_nothing_raised{
      evt1 = Event.create_basic!
      evt2 = Event.create!
    }
    evt1.reload
    evt2.reload
    assert evt1.event_group
    assert evt2.event_group
    refute_equal evt1.event_group, evt2.event_group
    assert_equal 0, evt2.event_items.size, "ev=#{evt2.inspect}"
    assert_equal 1, evt1.event_items.size, "ev=#{evt1.inspect}"

    evitem1= evt1.event_items.first
    assert       evitem1.unknown?

    hv1 = nil
    hv1 = HaramiVid.create_basic!
    hv1.event_items << evitem1
    refute evt1.destroyable?
    assert_raises(ActiveRecord::RecordNotDestroyed){ 
      evt1.destroy!
    }
    
    hv1.destroy
    evt1.reload
    assert_equal 1, evt1.event_items.size
    assert evt1.destroyable?
    assert_difference('Event.count', -1, "If only a single unknown EventItem remains, Event should be destroyable WITH the EventItem."){
      evt1.destroy!
    }
    assert evt1.destroyed?

    ### Translation unique within a parent
    evt1 = Event.create_basic!  # for some reason Translation is not created...
    evt1.with_translation(langcode: "fr", title: "Allo", is_orig: true)
    evt1.reload
    evt2 = evt1.dup
    evt2.note = "Test..."
    tra = evt1.translations.first.dup
    tra.translatable = nil
    evt2.unsaved_translations << tra
    assert_raises(ActiveRecord::RecordInvalid) {
      evt2.save!
      p [evt1, evt1]
    }
  end
end
