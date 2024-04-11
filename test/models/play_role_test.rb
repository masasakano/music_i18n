# coding: utf-8
# == Schema Information
#
# Table name: play_roles
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
#  index_play_roles_on_mname   (mname) UNIQUE
#  index_play_roles_on_weight  (weight)
#
require "test_helper"

class PlayRoleTest < ActiveSupport::TestCase
  test "uniqueness" do
    mdl0 = PlayRole.first.dup
    assert_raises(ActiveRecord::RecordInvalid){ # ActiveRecord::NotNullViolation at DB level
      PlayRole.create!(mname: nil,  weight: 12345) }
    assert_raises(ActiveRecord::RecordInvalid){ # ActiveRecord::NotNullViolation at DB level
      PlayRole.create!( weight: 12345) }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo", weight: nil) }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo", weight: "abc") }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo", weight: -4) }
    assert_raises(ActiveRecord::RecordInvalid){
      PlayRole.create!(mname: "naiyo") }  # This raises an Exception BECAUSE "unknown" has the weight of the DB-default 999.0

    mdl = PlayRole.new(mname: mdl0.mname, weight: 50)
    refute mdl.save
    mdl = PlayRole.new(mname: "naiyo", weight: mdl0.weight)
    refute mdl.save

    assert PlayRole.unknown.unknown?
    assert_equal PlayRole::UNKNOWN_TITLES['en'][1], PlayRole.unknown.alt_title(langcode: :en), "WARNING: This for some reason someitmes fails as a result of the alt_title of being nil.... PlayRole.unknown="+PlayRole.unknown.inspect

    ## checking fixtures
    tra = translations(:play_role_singer_en)
    assert_equal "Singer", tra.title
    assert_equal "en",   tra.langcode
    assert_equal "PlayRoleSingerEn", tra.note

    tra = translations(:play_role_singer_ja)
    assert_equal "ja",   tra.langcode
    assert_equal "歌手", tra.title
    assert_equal "singer", tra.translatable.mname
    assert_equal 10,       tra.translatable.weight

    tra = translations(:play_role_other_ja)
    assert_equal "その他", tra.title
  end
end
