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

  test "Domain.find_or_create_domain_by_url!" do
    urlstr = "https://www.youtube.com/watch?v=harami_vid1&lc=UgxffvDXzEaXVHqYcMF4AaABAg"
    dom = Domain.find_or_create_domain_by_url!(urlstr, site_category_id: nil)
    refute dom.errors.any?, dom.errors.messages.inspect
    assert dom.id

  end

  test "Domain.find_all_siblings_by_urlstr" do
    url_str = "abc.aruyo.com"
    d1 = Domain.find_or_create_domain_by_url!(       url_str, site_category_id: nil)
    d2 = Domain.find_or_create_domain_by_url!("www."+url_str, site_category_id: nil)
    dt1 = d1.domain_title
    d3 = Domain.create!(domain: "different-name.org", domain_title: dt1)

    exp = [d1, d2, d3]
    assert_equal exp, dt1.domains.order(:created_at), 'sanity check'

    assert_equal exp, Domain.find_all_siblings_by_urlstr(       url_str).order(:created_at).to_a
    assert_equal exp, Domain.find_all_siblings_by_urlstr("www."+url_str).order(:created_at).to_a
    assert_equal exp[0..1],
                      Domain.find_all_siblings_by_urlstr("www."+url_str, except: d3).order(:created_at).to_a
    assert_equal exp, Domain.find_all_siblings_by_urlstr("https://www."+url_str+"/").order(:created_at).to_a
    assert_equal exp, Domain.find_all_siblings_by_urlstr("https://www."+url_str+"/xyz.html").order(:created_at).to_a
    assert_equal  [], Domain.find_all_siblings_by_urlstr("random.non-existent.org").order(:created_at).to_a
  end

  test "Domain.extracted_normalized_domain" do
    assert_equal "abc.aruyo.com", Domain.extracted_normalized_domain("abc.aruyo.com/xyz")
    assert_equal "abc.aruyo.com", Domain.extracted_normalized_domain("https://abc.aruyo.com/xyz")
    assert_equal "youtu.be",      Domain.extracted_normalized_domain("youtu.be/yyy")
    urlstr = "https://www.youtube.com/watch?v=harami_vid1&lc=UgxffvDXzEaXVHqYcMF4AaABAg"
    assert_equal "youtu.be",      Domain.extracted_normalized_domain(urlstr)
  end
end
