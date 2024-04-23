# coding: utf-8
# == Schema Information
#
# Table name: channel_types
#
#  id                                                 :bigint           not null, primary key
#  mname(machine name (alphanumeric characters only)) :string           not null
#  note                                               :text
#  weight(weight for sorting within this model)       :integer          default(999), not null
#  created_at                                         :datetime         not null
#  updated_at                                         :datetime         not null
#  create_user_id                                     :bigint
#  update_user_id                                     :bigint
#
# Indexes
#
#  index_channel_types_on_create_user_id  (create_user_id)
#  index_channel_types_on_mname           (mname) UNIQUE
#  index_channel_types_on_update_user_id  (update_user_id)
#  index_channel_types_on_weight          (weight)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
require "test_helper"

class ChannelTypeTest < ActiveSupport::TestCase
  test "fixtures" do
    tra = translations(:channel_type_other_ja)
    assert_match(/^その他/, tra.alt_title)

    assert ChannelType.unknown
    tra = translations(:channel_type_unknown_en)
    assert_match(/^Unknown\b/, tra.title)
    assert tra.translatable
    assert_equal ChannelType.unknown, tra.translatable

    mdl = channel_types(:channel_type_main)
    assert_equal "main", mdl.mname
    assert_match(/^Primary\b/, mdl.best_translations[:en].title)

    assert_operator 101, :>, ChannelType.order(:weight).first.weight
    assert_operator 901, :<, ChannelType.order(:weight).last.weight
  end

  test "uniqueness" do
    #assert_raises(ActiveRecord::RecordInvalid){
    #  ChannelType.create!( note: "") }     # When no entries have the default value, this passes!
    mdl = ChannelType.new( mname: nil, weight: ChannelType.new_unique_max_weight )
    assert_raises(ActiveRecord::NotNullViolation){
      mdl.save!(validate: false) }
    refute  mdl.valid?

    mdl.mname = ChannelType.second.mname
    assert_raises(ActiveRecord::RecordNotUnique){
      mdl.save!(validate: false) }
    refute  mdl.valid?

    mdl.mname = "naiyo.nai"
    assert  mdl.valid?

    mdl.weight = nil
    assert_raises(ActiveRecord::NotNullViolation){
      mdl.save!(validate: false) }
    refute  mdl.valid?

    mdl.weight = "abc"
    refute  mdl.valid?
    mdl.weight = -4
    refute  mdl.valid?
  end

  test "associations" do
    assert_nothing_raised{ ChannelType.first.channels }
  end
end
