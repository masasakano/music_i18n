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

    assert dt.uris.exists?
    assert_raises(ActiveRecord::DeleteRestrictionError){
      dt.destroy}
    assert dt.uris.exists?
    # assert_raises(ActiveRecord::InvalidForeignKey){ # PG::ForeignKeyViolation  # At DB level.
    #   dt.delete }
    ### This would raise an error in the next access to the DB (I guess the Rails test frame fails?):
    # ActiveRecord::StatementInvalid: PG::InFailedSqlTransaction: ERROR:  current transaction is aborted, commands ignored until end of transaction block

    ## cascade deletion in the model-level.
    dt.uris.destroy_all
    dt.domains.reset
    assert_difference('DomainTitle.count', -1){
      assert_difference('Domain.count', -n_child_domains){
        dt.destroy
      }
    }
  end
end

