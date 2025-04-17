# == Schema Information
#
# Table name: domains
#
#  id                                                   :bigint           not null, primary key
#  domain(Domain or any subdomain such as abc.def.com)  :string
#  note                                                 :text
#  weight(weight to sort this model within DomainTitle) :float
#  created_at                                           :datetime         not null
#  updated_at                                           :datetime         not null
#  domain_title_id                                      :bigint           not null
#
# Indexes
#
#  index_domains_on_domain           (domain) UNIQUE
#  index_domains_on_domain_title_id  (domain_title_id)
#
# Foreign Keys
#
#  fk_rails_...  (domain_title_id => domain_titles.id) ON DELETE => cascade
#
require "test_helper"

class DomainTest < ActiveSupport::TestCase
  test "basic" do
    assert Domain.unknown
  end

  test "validations" do
    @domain_title = domain_titles(:one)

    rec = Domain.new(domain_title: @domain_title)
    rec.domain = ""
    refute rec.valid?, "presence of domain-check failed."

    rec = domains(:one).dup
    # rec.save!  # => ActiveRecord::RecordNotUnique: PG::UniqueViolation
    refute rec.valid?, "refute due to unique constraint (on domain)"
    rec.domain += "abc"
    assert rec.valid?, "unique constraint (on domain)"

    rec.domain_title = nil
    refute rec.valid?

    rec.domain_title = @domain_title
    assert rec.valid?

    user_assert_model_weight(rec, allow_nil: true)  # defined in test_helper.rb

    core_domain = "www.naiyo.museum"
    rec.domain = "https://#{core_domain}:80/abc"
    refute rec.valid?
    rec.domain = "https://#{core_domain}:80/"
    assert rec.valid?

    rec.save!
    assert_equal core_domain, rec.domain, "should be normalized, but..."
  end
end
