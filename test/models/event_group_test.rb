# coding: utf-8
# == Schema Information
#
# Table name: event_groups
#
#  id                                                                                          :bigint           not null, primary key
#  end_date(if null, end date is undefined.)                                                   :date
#  end_date_err(Error of end-date in day. 182 or 183 days for one with only a known year.)     :integer
#  note                                                                                        :text
#  start_date(if null, start date is undefined.)                                               :date
#  start_date_err(Error of start-date in day. 182 or 183 days for one with only a known year.) :integer
#  created_at                                                                                  :datetime         not null
#  updated_at                                                                                  :datetime         not null
#  place_id                                                                                    :bigint
#  memo_editor(Internal memo for Editors)                                                      :text
#
# Indexes
#
#  index_event_groups_on_end_date    (end_date)
#  index_event_groups_on_place_id    (place_id)
#  index_event_groups_on_start_date  (start_date)
#
# Foreign Keys
#
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
require "test_helper"

class EventGroupTest < ActiveSupport::TestCase
  test "consistency on fixtures and translations" do
    EventGroup.all.each do |model|
      assert model.translations.exists?, "No translation is found for EventGroup=#{model.inspect}"
    end
  end

  test "on delete" do
    evgr = event_groups(:evgr_lucky2023)

    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(start_date_err: -8) }
    evgr.reload # must exist
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(end_date_err: -8) }
    evgr.reload
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(end_date_err: "a") }
    evgr.reload

    assert_equal 2023, evgr.start_date.year, "sanity check"
    pla = evgr.place
    assert pla
    refute pla.prefecture.unknown?

    ## testing:  ON DELETE => nullify
    pla.destroy!
    evgr.reload
    assert_nil evgr.place, "Though it should be changed into a different value when Place is destroyed, it has to be technically allowed to be nullified."

    ## testing:  has_many :events, dependent: :restrict_with_exception
    refute_empty evgr.events, "sanity check..."
    assert_raises(ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError, "EVGR=#{evgr.inspect}\n events=#{evgr.events.inspect}"){ evgr.destroy! } # At DB level, <ActiveRecord::InvalidForeignKey> for <"PG::ForeignKeyViolation: ERROR:  update or delete on table "event_groups" violates foreign key constraint "fk_rails_..." on table "events"  DETAIL:  Key (id)=(804171372) is still referenced from table "events".> # ActiveRecord::RecordNotDestroyed is at Rails level.

    # Once the children are destoryed, it is destroyable, except for unknown.
    evione = event_items(:one)
    refute evione.destroyable?
    assert_raises(ActiveRecord::DeleteRestrictionError){evione.destroy}
    evgr.reload
    evgr.events.each do |eev|
      refute eev.event_items.all?{|i| i.destroyable?}
      assert_raises(ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError){  # At DB level, <ActiveRecord::InvalidForeignKey> for <"PG::ForeignKeyViolation: ERROR:  update or delete on table "event_groups" violates foreign key constraint "fk_rails_..." on table "events"  DETAIL:  Key (id)=(804171372) is still referenced from table "events".>
      eev.event_items.destroy_all }  # failed.
      eev.event_items.each do |eevit|
        eevit.harami_vids.destroy_all  # You cannot delete it with Event#harami_vids.destroy_all  because of ActiveRecord::HasManyThroughNestedAssociationsAreReadonly
        eevit.harami1129s.destroy_all
        eevit.destroy! if eevit.destroyable?
      end
      assert eev.event_items.exists?
    end
    evgr.reload  # essential.

    assert_operator 0, :<, evgr.events.count
    refute evgr.destroyable?
    evgr.events.each do |eev|
      eev.destroy! if eev.destroyable?
    end

    evgr.reload
    assert_equal 1, evgr.events.count, "#{evgr.events.inspect}"
    assert  evgr.events.first.unknown?
    evt_tra_size = evgr.events.first.translations.count
    assert_equal 3, evt_tra_size, "#{evgr.events.first.translations.inspect}"  # fixtures should be set so as to simulate the real application.
    assert_equal "fr", translations(:ev_evgr_unknown_unknown_fr).langcode, "to test fixtures..."

    assert evgr.destroyable?
    assert_difference('Translation.count', -4){
      assert_difference('Event.count', -1){
        assert_difference('EventGroup.count', -1){
          evgr.destroy! } } }
    assert evgr.destroyed?

    assert_difference('Translation.count', 4){
      assert_difference('EventItem.count'){
        assert_difference('Event.count'){
          assert_difference('EventGroup.count'){
            EventGroup.create_basic!
            tras = Translation.order(created_at: :desc).limit(4)
            assert_equal %w(Event Event Event EventGroup), tras.pluck(:translatable_type), "Three for unknown Events and one for the new CreateEvent (EventItem is not BaseWithTranslation)"
          } } } }
  end

  test "mass-delete" do
    evgr = event_groups(:evgr_lucky2023)
    evgr.events.each do |eev|
      if eev.harami_vids.exists?
        refute evgr.destroyable?
        refute eev.destroyable?
        eev.event_items.each do |evit|
          evit.harami_vids.destroy_all 
          if evit.harami1129s.exists?
            evit.harami1129s.each do |eh|
              eh.update! event_item: nil  # nullify Harami1129's ref
            end
          end
          evit.reload  # Essential!
          evit.destroy if !evit.unknown?
        end
        assert_equal 1, eev.event_items.count
        eev.reload
        evit = eev.event_items.first
        refute evit.siblings.exists?, "self=#{[evit.id, evit.machine_title]}, siblings=#{evit.siblings.pluck(:id, :machine_title).inspect}"
        refute evit.destroyable?
        assert_raises(ActiveRecord::RecordNotDestroyed, "last remaining EventItem cannot be destroyed."){  # Rails-level destroy-validation
          evit.destroy! }
      end
      assert eev.destroyable? if !eev.unknown?
      eev.destroy if !eev.unknown?
    end
    assert_equal 1, evgr.events.count
    eev = evgr.events.first
    refute eev.destroyable?  # unknown? is never destroyable? but it can be deleted when the parent EventGroup can be and is destroyed.
    assert evgr.destroyable?
    assert_difference('EventItem.count', -1){
      eev.destroy }  # EventItem and Event must be destroyable.
  end

  test "ApplicationRecord.allow_destroy_all for EventGroup" do
    evgr = EventGroup.create_basic!
    assert_equal 1, evgr.event_items.count
    assert_equal 1, evgr.events.count
    assert_difference('Event.count', 0, "Sole unknown Event should not be destroyed in default, but..."){
     assert_difference('EventItem.count', 0, "Sole unknown EventItem should not be destroyed in default, but..."){
       evgr.events.each do |evt|
         assert_raise(ActiveRecord::RecordNotDestroyed){
           evt.event_items.destroy_all }
       end
     } }

    refute ApplicationRecord.allow_destroy_all, "sanity check of the default App..."
    begin
      ApplicationRecord.allow_destroy_all=true  # now allowing destroy
      assert_difference('Event.count', -1){
       assert_difference('EventItem.count', -1){
        evgr.events.destroy_all } }
    ensure
      ApplicationRecord.allow_destroy_all=false
    end
  end

  test "date order" do
    evgr = EventGroup.create!(start_date: Date.new(2000, 3, 3), end_date: Date.new(2000, 3, 1), start_date_err: 0)  # should be OK because end_date_err is nil
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(start_date_err: -8) }
    evgr.reload
    assert_nothing_raised{ evgr.update!(end_date_err: 5) }
    assert_nothing_raised{ evgr.update!(end_date_err: evgr.end_date_err_previously_was) }  # reverted
    assert_nil evgr.end_date_err
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(end_date_err: 1) }  # 1 day is too short.
    evgr.reload
    assert_nothing_raised{ evgr.update!(end_date_err: 2) }
    evgr.reload
    assert_nothing_raised{ evgr.update!(start_date_err: 1, end_date_err: 2) }
    evgr.reload
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(start_date_err: 1, end_date_err: 0) }  # 1 day is too short.
    evgr.reload
    assert_nothing_raised{                      evgr.update!(start_date_err: 0, end_date_err: 0, start_date: Date.new(2000, 2, 25)) } # errors do not matter.
    evgr.reload
    assert_nothing_raised{                      evgr.update!(start_date_err: 0, end_date_err: 0, start_date: Date.new(2000, 3, 1)) }  # Same day is OK.
    evgr.reload
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(start_date_err: 0, end_date_err: 0, start_date: Date.new(2000, 3, 5)) }
    evgr.reload
    assert_nothing_raised{                      evgr.update!(start_date_err: nil,end_date_err: 0, start_date: Date.new(2000, 3, 5)) }
  end

  test "self.guessed_best_or_nil" do
    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: nil, ref_title: nil, year: nil)
    assert_nil evgr 

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: countries(:japan), ref_title: "ストリートピアノだよ", year: nil)
    assert_nil evgr 

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: countries(:france), ref_title: nil, year: nil)
    exp  = event_groups(:evgr_paris2023)
    assert_equal exp, evgr 

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: nil, ref_title: "パリの駅で", year: nil)
    exp  = event_groups(:evgr_paris2023)
    assert_equal exp, evgr 

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: countries(:uk), ref_title: nil, year: nil)
    exp  = event_groups(:evgr_uk2024)
    assert_equal exp, evgr 

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: nil, ref_title: "イギリスにきました", year: nil)
    exp  = event_groups(:evgr_uk2024)
    assert_equal exp, evgr 

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: countries(:france), ref_title: nil, year: 2030)
    assert_nil  evgr, "this should not be 2023 Paris EventGroup, but..."

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: nil, ref_title: "急に生配信するよ", year: 2025)
    exp  = event_groups(:evgr_live_streamings)
    assert_equal exp, evgr

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: nil, ref_title: "今日はテレビの話", year: 2025)
    exp  = event_groups(:evgr_tv)
    assert_equal exp, evgr

    evgr = EventGroup.guessed_best_or_nil(:HaramiVid, place: nil, ref_title: "ハラミラジオでコラボ", year: 2025)
    exp  = event_groups(:evgr_radio)
    assert_equal exp, evgr
  end

  test "unknown_event" do
    ## Preparation
    max_error_day = TimeAux::MAX_ERROR.in_days.ceil + 1  # = 3652060 [days]
    evgr = EventGroup.create_basic!(title: "My New EventGroup", langcode: "en", is_orig: true,
                                    start_date: TimeAux::DEF_FIRST_DATE_TIME,
                                    start_date_err: max_error_day,
                                    end_date:   TimeAux::DEF_LAST_DATE_TIME,
                                    end_date_err:   max_error_day,
                                    place: Place.unknown)
    evgr.events.reset
    assert_equal 1, evgr.events.count
    assert (ev_unk=evgr.unknown_event(force: false))
    evt2 = Event.initialize_with_def_time(title: "A New Event2", langcode: "en", is_orig: true, event_group: evgr)
    evt2.save!
    evgr.events.reset
    assert_equal 2, evgr.events.count

    ev_unk.event_items.first.delete
    ev_unk.delete
    evgr.events.reset
    assert_equal 1, evgr.events.count

    refute  evgr.unknown_event(force: false)
    assert (ev_unk2=evgr.unknown_event)
    evgr.events.reset
    assert  evgr.unknown_event(force: false)
    assert_equal ev_unk2, evgr.unknown_event(force: false)
    assert_equal 2, evgr.events.count
    assert_equal ev_unk2, evgr.unknown_event(force: true), "should not create a new one, but..."
  end

  test "self.default" do
    evgr = EventGroup.default(context=nil, place: nil)
    exp = EventGroup.unknown
    assert_equal exp, evgr 

    evgr = EventGroup.default(context=:Harami1129)
    exp = event_groups(:evgr_single_streets)
    assert_equal exp, evgr 

    evgr = EventGroup.default(:HaramiVid, place: nil, ref_title: "急に生配信するよ", year: 2025)
    exp  = event_groups(:evgr_live_streamings)
    assert_equal exp, evgr
  end

  test "association" do
    eg = EventGroup.first
    assert_nothing_raised{ eg.events }
    assert_nothing_raised{ eg.event_items }
    assert_nothing_raised{ eg.harami_vids }
  end

  test "callbacks" do
    eg = nil
    assert_difference('EventGroup.count + Event.count + EventItem.count', 3) {
      eg = EventGroup.create_basic!(start_date: Date.new(2005, 8, 15))
    }
    assert_equal Place.unknown, eg.place
    assert_equal EventGroup.unknown, eg.unknown_sibling
    assert  eg.start_date
    assert  eg.end_date
    eg.reload
    assert eg.unknown_event, "events = "+eg.events.inspect
    assert_equal 1, eg.events.size
    evt = eg.events.first
    assert_equal eg.start_date.year, evt.start_time.year, "StartDate=#{eg.start_date.inspect} Event=#{evt.inspect}"
    assert_equal 12, evt.start_time.hour, "Event=#{evt.inspect}"  # midday
    assert_nil evt.duration_hour

    evt = Event.initialize_basic
    evt.event_group = nil
    assert_nil evt.event_group_id
    assert_difference('Event.count') {
      eg.events << evt
    }
    eg.reload
    assert_equal 2, eg.events.size
  end

end
