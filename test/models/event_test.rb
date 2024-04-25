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
  end
end
