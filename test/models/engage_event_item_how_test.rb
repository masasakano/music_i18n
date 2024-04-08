# == Schema Information
#
# Table name: engage_event_item_hows
#
#  id                                                  :bigint           not null, primary key
#  mname(unique machine name)                          :string           not null
#  note                                                :text
#  weight(weight to sort entries in Index for Editors) :float            default(999.0), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
# Indexes
#
#  index_engage_event_item_hows_on_mname   (mname) UNIQUE
#  index_engage_event_item_hows_on_weight  (weight)
#
require "test_helper"

class EngageEventItemHowTest < ActiveSupport::TestCase
  test "uniqueness" do
    mdl0 = EngageEventItemHow.first.dup
    assert_raises(ActiveRecord::RecordInvalid){ # ActiveRecord::NotNullViolation at DB level
      EngageEventItemHow.create!(mname: nil,  weight: 12345) }
    assert_raises(ActiveRecord::RecordInvalid){ # ActiveRecord::NotNullViolation at DB level
      EngageEventItemHow.create!( weight: 12345) }
    assert_raises(ActiveRecord::RecordInvalid){
      EngageEventItemHow.create!(mname: "naiyo", weight: nil) }
    assert_raises(ActiveRecord::RecordInvalid){
      EngageEventItemHow.create!(mname: "naiyo") }  # This raises an Exception BECAUSE "unknown" has the weight of the DB-default 999.0

    mdl = EngageEventItemHow.new(mname: mdl0.mname, weight: 50)
    refute mdl.save
    mdl = EngageEventItemHow.new(mname: "naiyo", weight: mdl0.weight)
    refute mdl.save
  end
end
