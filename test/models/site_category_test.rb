# coding: utf-8
# == Schema Information
#
# Table name: site_categories
#
#  id                                         :bigint           not null, primary key
#  mname(Unique machine name)                 :string           not null
#  note                                       :text
#  memo_editor(Internal-use memo for Editors) :text
#  summary(Short summary)                     :text
#  weight                                     :float
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#
# Indexes
#
#  index_site_categories_on_mname    (mname) UNIQUE
#  index_site_categories_on_summary  (summary)
#  index_site_categories_on_weight   (weight)
#
require "test_helper"

class SiteCategoryTest < ActiveSupport::TestCase
  test "uniqueness" do
    #assert_raises(ActiveRecord::RecordInvalid){
    #  SiteCategory.create!( note: "") }     # When no entries have the default value, this passes!
    mdl = SiteCategory.new( mname: nil, weight: SiteCategory.new_unique_max_weight )
    assert_raises(ActiveRecord::NotNullViolation){
      mdl.save!(validate: false) }
    refute  mdl.valid?

    mdl.mname = SiteCategory.second.mname
    assert_raises(ActiveRecord::RecordNotUnique){
      mdl.save!(validate: false) }
    refute  mdl.valid?

    mdl.mname = "naiyo.nai"
    assert  mdl.valid?

  end

  test "validation" do
    mdl = site_categories(:one)
    user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb
  end

  test "associations" do
    # assert_nothing_raised{ SiteCategory.first.uris }
  end
end
