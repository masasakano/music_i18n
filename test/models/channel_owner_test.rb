# coding: utf-8
# == Schema Information
#
# Table name: channel_owners
#
#  id                                         :bigint           not null, primary key
#  note                                       :text
#  themselves(true if identical to an Artist) :boolean          default(FALSE)
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  create_user_id                             :bigint
#  update_user_id                             :bigint
#
# Indexes
#
#  index_channel_owners_on_create_user_id  (create_user_id)
#  index_channel_owners_on_themselves      (themselves)
#  index_channel_owners_on_update_user_id  (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
require "test_helper"

class ChannelOwnerTest < ActiveSupport::TestCase
  test "fixtures" do
    assert ChannelOwner.unknown
    tra = translations(:channel_owner_unknown_en)
    assert_match(/^Unknown\b/, tra.title)
    assert tra.translatable
    assert_equal ChannelOwner.unknown, tra.translatable

    mdl = channel_owners(:channel_owner_haramichan)
    assert        mdl.themselves
    assert_equal "HARAMIchan", mdl.best_translations[:en].title

    mdl = channel_owners(:channel_owner_saki_kubota)
    assert        mdl.themselves
    assert_equal artists(:artist_saki_kubota).title, mdl.best_translations[:ja].title
  end

  test "uniqueness" do
    #assert_raises(ActiveRecord::RecordInvalid){
    #  ChannelOwner.create!( note: "") }     # When no entries have the default value, this passes!
    hstra = {langcode: "en", title: "A B Smith", is_orig: true}
    mdl1 = ChannelOwner.new( themselves: false )
    mdl1.unsaved_translations << Translation.new(hstra)
    mdl1.save!

    mdl2 = ChannelOwner.new( themselves: false )
    mdl2.unsaved_translations << Translation.new(hstra)
    #refute  mdl2.valid?  # This should refute!
    assert_raise(ActiveRecord::RecordInvalid){
      mdl2.save! }
  end

  test "associations" do
    assert_nothing_raised{ ChannelOwner.first.channels }
  end
end
