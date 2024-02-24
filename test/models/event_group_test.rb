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

    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(start_year: -8) }
    evgr.reload
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(start_day: -2) }
    evgr.reload
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(end_month: 15) }
    evgr.reload
    assert_raises(ActiveRecord::RecordInvalid){ evgr.update!(end_day:   32) }

    evgr.reload
    assert_equal 2023, evgr.start_year
    pla = evgr.place
    assert pla
    refute pla.prefecture.unknown?

    pla.destroy
    evgr.reload
    assert_nil evgr.place, "Though it should be changed into a different value when Place is destroyed, it has to be technically allowed to be nullified."
  end
end
