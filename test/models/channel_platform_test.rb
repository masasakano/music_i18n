# coding: utf-8
# == Schema Information
#
# Table name: channel_platforms
#
#  id                                                 :bigint           not null, primary key
#  mname(machine name (alphanumeric characters only)) :string           not null
#  note                                               :text
#  created_at                                         :datetime         not null
#  updated_at                                         :datetime         not null
#  create_user_id                                     :bigint
#  update_user_id                                     :bigint
#
# Indexes
#
#  index_channel_platforms_on_create_user_id  (create_user_id)
#  index_channel_platforms_on_mname           (mname) UNIQUE
#  index_channel_platforms_on_update_user_id  (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
require "test_helper"

class ChannelPlatformTest < ActiveSupport::TestCase
  test "fixtures" do
    tra = translations(:channel_platform_other_ja)
    assert_match(/^その他/, tra.title)
    tra = translations(:channel_platform_unknown_en)
    assert_match(/^Unknown\b/, tra.title)
    assert tra.translatable
    assert_equal ChannelPlatform.unknown, tra.translatable
  end

  test "uniqueness" do
    #assert_raises(ActiveRecord::RecordInvalid){
    #  ChannelPlatform.create!( note: "") }     # When no entries have the default value, this passes!
    mdl = ChannelPlatform.new( mname: nil)
    assert_raises(ActiveRecord::NotNullViolation){
      mdl.save!(validate: false) }
    refute  mdl.valid?

    mdl = ChannelPlatform.new( mname: ChannelPlatform.second.mname )
    assert_raises(ActiveRecord::RecordNotUnique){
      mdl.save!(validate: false) }
    refute  mdl.valid?
  end

end
