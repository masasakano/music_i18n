# == Schema Information
#
# Table name: event_groups
#
#  id                                                                :bigint           not null, primary key
#  end_day                                                           :integer
#  end_month                                                         :integer
#  end_year                                                          :integer
#  note                                                              :text
#  order_no(Serial number for a series of Event Group, e.g., 5(-th)) :integer
#  start_day                                                         :integer
#  start_month                                                       :integer
#  start_year                                                        :integer
#  created_at                                                        :datetime         not null
#  updated_at                                                        :datetime         not null
#  place_id                                                          :bigint
#
# Indexes
#
#  index_event_groups_on_order_no     (order_no)
#  index_event_groups_on_place_id     (place_id)
#  index_event_groups_on_start_day    (start_day)
#  index_event_groups_on_start_month  (start_month)
#  index_event_groups_on_start_year   (start_year)
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
