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

    pla.destroy
    evgr.reload
    assert_nil evgr.place, "Though it should be changed into a different value when Place is destroyed, it has to be technically allowed to be nullified."
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
end
