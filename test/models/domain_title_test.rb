# == Schema Information
#
# Table name: domain_titles
#
#  id                                         :bigint           not null, primary key
#  memo_editor(Internal-use memo for Editors) :text
#  note                                       :text
#  weight(weight to sort this model index)    :float
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  site_category_id                           :bigint           not null
#
# Indexes
#
#  index_domain_titles_on_site_category_id  (site_category_id)
#  index_domain_titles_on_weight            (weight)
#
# Foreign Keys
#
#  fk_rails_...  (site_category_id => site_categories.id)
#
require "test_helper"

class DomainTitleTest < ActiveSupport::TestCase

  test "weight validations" do
    mdl = domain_titles(:one)
    user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb
  end

  test "associations" do
    dname = domain_titles(:one)
    assert dname.site_category
    assert dname.valid?
    dname.site_category = nil
    refute dname.valid?
  end

  test "has_many domains" do
    d1 = Domain.new(domain: "a.xyz.com")
    d2 = Domain.new(domain: "b.xyz.com")
    dt = domain_titles(:one)

    assert_difference('dt.domains.count', 2){
      assert_difference('Domain.count', 2){
        dt.domains << d1
        dt.domains << d2
      }
    }
    assert d1.id
    assert d2.id
    assert_equal dt, d1.domain_title
    assert_equal dt, d2.domain_title
    n_child_domains = dt.domains.count
    assert_operator 2, :<=, n_child_domains

    assert dt.urls.exists?
    assert_raises(ActiveRecord::DeleteRestrictionError){
      dt.destroy}
    assert dt.urls.exists?
    # assert_raises(ActiveRecord::InvalidForeignKey){ # PG::ForeignKeyViolation  # At DB level.
    #   dt.delete }
    ### This would raise an error in the next access to the DB (I guess the Rails test frame fails?):
    # ActiveRecord::StatementInvalid: PG::InFailedSqlTransaction: ERROR:  current transaction is aborted, commands ignored until end of transaction block

    ## cannot cascade deletion in the model-level because of dependent (grandchildren) Urls.
    assert dt.urls.exists?
    assert_raises(ActiveRecord::DeleteRestrictionError){
      dt.domains.destroy_all
    }

    dt.urls.each do |url|
      url.destroy
    end

    #assert_nothing_raised(){
    #  dt.domains.destroy_all
    #}
    dt.domains.reset
    assert_difference('DomainTitle.count', -1){  # cascade destruction of Domains is allowed unless there are dependent Urls
      assert_difference('Domain.count', -n_child_domains){
        dt.destroy
      }
    }
  end

  test "DomainTitle.new_from_url and .find_by_urlstr" do
    url = "abc.naiyo.com"
    dt = DomainTitle.new_from_url("www."+url)
    assert dt.new_record?
    assert dt.valid?
    assert_equal url, dt.title

    ### DomainTitle.find_by_urlstr

    url_str = "abc.naiyo.com"
    d1 = Domain.find_or_create_domain_by_url!(       url_str, site_category_id: nil)
    d2 = Domain.find_or_create_domain_by_url!("www."+url_str, site_category_id: nil)
    dt1 = d1.domain_title
    d3 = Domain.create!(domain: "different-name.org", domain_title: dt1)
    assert_equal [d1, d2, d3], dt1.domains.order(:created_at)

    assert_equal dt1, DomainTitle.find_by_urlstr(       url_str)
    assert_equal dt1, DomainTitle.find_by_urlstr("www."+url_str)
    assert_equal dt1, DomainTitle.find_by_urlstr("https://www."+url_str+"/")
    assert_equal dt1, DomainTitle.find_by_urlstr("https://www."+url_str+"/xyz.html")
  end
end

