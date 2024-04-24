# == Schema Information
#
# Table name: event_groups
#
#  id                                                                                          :bigint           not null, primary key
#  end_date(if null, end date is undefined.)                                                   :date
#  end_date_err(Error of end-date in day. 182 or 183 days for one with only a known year.)     :integer
#  note                                                                                        :text
#  order_no(Serial number for a series of Event Group, e.g., 5(-th))                           :integer
#  start_date(if null, start date is undefined.)                                               :date
#  start_date_err(Error of start-date in day. 182 or 183 days for one with only a known year.) :integer
#  created_at                                                                                  :datetime         not null
#  updated_at                                                                                  :datetime         not null
#  place_id                                                                                    :bigint
#
# Indexes
#
#  index_event_groups_on_end_date    (end_date)
#  index_event_groups_on_order_no    (order_no)
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
    pla.destroy
    evgr.reload
    assert_nil evgr.place, "Though it should be changed into a different value when Place is destroyed, it has to be technically allowed to be nullified."

    ## testing:  has_many :events, dependent: :restrict_with_exception
    refute_empty evgr.events, "sanity check..."
    assert_raises(ActiveRecord::DeleteRestrictionError){ evgr.destroy } # At DB level, <ActiveRecord::InvalidForeignKey> for <"PG::ForeignKeyViolation: ERROR:  update or delete on table "event_groups" violates foreign key constraint "fk_rails_..." on table "events"  DETAIL:  Key (id)=(804171372) is still referenced from table "events".>

    # Once the children are destoryed, it is destroyable.
    evgr.events.each do |eev|
      assert_raises(ActiveRecord::DeleteRestrictionError){  # At DB level, <ActiveRecord::InvalidForeignKey> for <"PG::ForeignKeyViolation: ERROR:  update or delete on table "event_groups" violates foreign key constraint "fk_rails_..." on table "events"  DETAIL:  Key (id)=(804171372) is still referenced from table "events".>
      eev.event_items.destroy_all }  # failed.
      eev.event_items.each do |eevit|
        eevit.harami_vids.destroy_all  # You cannot delete it with Event#harami_vids.destroy_all  because of ActiveRecord::HasManyThroughNestedAssociationsAreReadonly
      end
      eev.event_items.destroy_all
      eev.destroy
    end
    evgr.reload  # essential.
    assert_nothing_raised{ evgr.destroy }
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

  test "association" do
    eg = EventGroup.first
    assert_nothing_raised{ eg.events }
    assert_nothing_raised{ eg.event_items }
    assert_nothing_raised{ eg.harami_vids }
  end
end
