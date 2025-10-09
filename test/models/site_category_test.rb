# coding: utf-8
# == Schema Information
#
# Table name: site_categories
#
#  id                                         :bigint           not null, primary key
#  memo_editor(Internal-use memo for Editors) :text
#  mname(Unique machine name)                 :string           not null
#  note                                       :text
#  summary(Short summary)                     :text
#  weight(weight to sort this model in index) :float
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

  #test "associations" do
  #  # assert_nothing_raised{ SiteCategory.first.uris }
  #end

  test "default" do
    sc1 = site_categories(:site_category_other)
    assert (scd=SiteCategory.default)
    assert_equal sc1, scd
    assert scd.default?
    refute site_categories(:site_category_unknown).default?
  end

  test "SiteCategory.find_by_urlstr" do
    ### SiteCategory.find_by_urlstr
    sc_media = site_categories(:site_category_media)

    url_str = "abc.naiyo.com"
    d1 = Domain.find_or_create_domain_by_url!(       url_str, site_category_id: nil)
    d2 = Domain.find_or_create_domain_by_url!("www."+url_str, site_category_id: nil)
    dt1 = d1.domain_title
    dt1.update!(site_category: sc_media)
    d3 = Domain.create!(domain: "different-name.org", domain_title: dt1)
    assert_equal [d1, d2, d3], dt1.domains.order(:created_at), 'sanity check'

    assert_equal sc_media, SiteCategory.find_by_urlstr(       url_str)
    assert_equal sc_media, SiteCategory.find_by_urlstr("www."+url_str)
    assert_equal sc_media, SiteCategory.find_by_urlstr("https://www."+url_str+"/")
    assert_equal sc_media, SiteCategory.find_by_urlstr("https://www."+url_str+"/xyz.html")
  end
end
