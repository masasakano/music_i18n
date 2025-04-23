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
    assert_equal core_domain, rec.reload.domain, "should be normalized, but..."
  end

  test "self.guess_site_category" do
    scat = site_categories(:site_category_chronicle)
    dom_obj = scat.domains.first
    ar = dom_obj.domain.split(".")
    assert_equal scat, Domain.guess_site_category(dom_obj.domain)
    assert_equal scat, Domain.guess_site_category("https://"+dom_obj.domain)
    u = ar[-2..-1].join(".")
    assert_equal scat, Domain.guess_site_category(u)
    assert_equal scat, Domain.guess_site_category("https://"+u)
    u = "abc.def-ghi."+ar[-2..-1].join(".")
    assert_equal scat, Domain.guess_site_category(u)
    assert_equal scat, Domain.guess_site_category("https://"+u+"/xxx.html?y=5")
  end

  test "reset_site_category" do
    scat = site_categories(:site_category_chronicle)
    dom  = domains(:one)
    dtit = dom.domain_title
    assert_equal dom.site_category, dtit.site_category, "sanity check"
    refute_equal scat,  dom.site_category, "testing fixtures"

    dom_tmpl = scat.domains.first
    ar = dom_tmpl.domain.split(".")
    url_str = "https://ab.cd.ef.ghi-jk."+ar[-2..-1].join(".")+"/xxx/yy#zz"
    
    dom.reset_site_category!(url_str)
    assert_equal scat,  dom.reload.site_category
    assert_equal scat, dtit.reload.site_category
#  end
#
#  test "create_basic!" do
#    url_str = "https://ab.cd.ef.ghi-jk."+ar[-2..-1].join(".")+"/xxx/yy#zz"
#    scat = site_categories(:site_category_chronicle)
#    dom  = domains(:one)
#    dom.reset_site_category!(url_str)
    dom2 = Domain.create_basic!(domain: "abcdefg."+dom.domain, site_category_id: "")
    assert_equal scat,  dom2.site_category
  end
end
