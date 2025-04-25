# coding: utf-8
# == Schema Information
#
# Table name: urls
#
#  id                                              :bigint           not null, primary key
#  last_confirmed_date                             :date
#  memo_editor                                     :text
#  note                                            :text
#  published_date                                  :date
#  url(valid URL/URI including https://)           :string           not null
#  url_langcode(2-letter locale code)              :string
#  url_normalized(URL part excluding https://www.) :string
#  weight(weight to sort this model)               :float
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  create_user_id                                  :bigint
#  domain_id                                       :bigint           not null
#  update_user_id                                  :bigint
#
# Indexes
#
#  index_urls_on_create_user_id        (create_user_id)
#  index_urls_on_domain_id             (domain_id)
#  index_urls_on_last_confirmed_date   (last_confirmed_date)
#  index_urls_on_published_date        (published_date)
#  index_urls_on_update_user_id        (update_user_id)
#  index_urls_on_url                   (url)
#  index_urls_on_url_and_url_langcode  (url,url_langcode) UNIQUE
#  index_urls_on_url_langcode          (url_langcode)
#  index_urls_on_url_normalized        (url_normalized)
#  index_urls_on_weight                (weight)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (domain_id => domains.id)
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
require "test_helper"

class UrlTest < ActiveSupport::TestCase
  test "validation" do
    url1 = urls(:one)
    assert url1, "fixture testing"
    user_assert_model_weight(url1, allow_nil: true)  # defined in test_helper.rb

    url = url1.dup

    refute url.valid?, "err=#{url.valid?; url.errors.inspect}"  # URL duplication
    url.url = nil
    refute url.valid?  # presence
    urlstr = "https://validate.example.com/xyz"
    url.url = urlstr
    assert url.valid?

    url.domain = nil
    refute url.valid?, "err=#{url.valid?; url.errors.inspect}"  # No belongs_to
    url.domain = url1.domain
    assert url.valid?

    url.domain_id = ""
    refute url.valid?
    refute url.save
    url.domain = url1.domain
    assert url.valid?

    url.url_langcode = nil
    assert_nil url.url_langcode
    url.url_langcode = "naiyo"
    refute url.valid?
    url.url_langcode = "ZH"
    assert url.valid?
    url.save!
    refute url.valid?, "Lack of Translation (for non-new_record) should mean not valid, but..."
    url.translations << Translation.new(title: "new #{__method__} 88", langcode: "en")
    assert url.valid?, "errors="+url.errors.inspect

    url.reload
    assert_equal "zh", url.url_langcode # became lower-case

    assert url.valid?, "errors="+url.errors.inspect

    urlstr1 = "www.MySite.com:443/ABC"
    url1 = Url.new(url: "https://"+urlstr1, domain: Domain.first)
    url1.unsaved_translations << Translation.new(title: "url-1", langcode: "en")
    url1.save!
    urlstr2 = ("http://"+urlstr1.downcase).sub(/443/, "80")  # Protocol is "http" (NOT https), ports differ, cases for both Domain and Path differ. Some differences are significant IN PRINCIPLE, but they are regarded as identical here.
    url2 = Url.new(url: urlstr2, domain: Domain.second)
    url2.unsaved_translations << Translation.new(title: "url-2", langcode: "en")
    refute url2.valid?, "validate should fail because case-insensitive URL, and schemes and ports do not matter, but..."
  end

  test "unknown" do
    assert(url=Url.unknown, Url.all.inspect)
    assert url.unknown?
  end

  test "Url.normalized_url" do
    s = "example.com/abc?q=1&r=2#xyz"
    assert_equal s, Url.normalized_url("ftp://www."+s)

    s = "www.x/invalid/"
    assert_equal s, Url.normalized_url(s)

    s = "http://abc.com/"
    assert_equal "abc.com", Url.normalized_url(s), "should have no trailing slash, but..."

    s = "abc.com/?q="
    assert_equal s, Url.normalized_url("https://"+s)

    s = "https://"+(s1="お名前.com")+":8080"+(s2="/some/path?q=日本語&r=国&w=ABC#zy")
    assert_equal s1+s2, Url.normalized_url(s)
    assert_equal s1+s2, Url.normalized_url(Addressable::URI.encode(s))

    s0 = s.sub(/\.com/, ".COM")
    encoded = Addressable::URI.encode(s0)
    refute_equal s, encoded, 'sanity check'
    newurl = Url.new(url: encoded, domain: Domain.first)
    newurl.unsaved_translations << Translation.new(title: "tekito", langcode: "en")
    newurl.save!
    assert_equal encoded, newurl.url,            'shuld be raw, but...'
    assert_equal s1+s2,   newurl.url_normalized, 'shuld be decoded+downcased, but...'

    # changes it to test :update
    newurl.update!(url: "another.com")
    refute_equal encoded, newurl.url
    refute_equal s1+s2,   newurl.url_normalized
    newurl.update!(url: encoded)
    assert_equal encoded, newurl.url,            'shuld be raw (again), but...'
    assert_equal s1+s2,   newurl.url_normalized, 'shuld be decoded+downcased (again), but...'
  end

  test "normalized url" do
    dt = DomainTitle.unknown
    pri_domain_str = dt.primary_domain.domain
    assert pri_domain_str, 'sanity check'
    url_root = pri_domain_str.sub(%r@^(https?://)?(www\.)?@, "fff.")
    url_str = "https://"+url_root.capitalize.sub(/\.com/, ".COM")
    url_exp = url_root

    url = Url.create_basic!(url: url_str)
    assert_equal url_str, url.url
    assert_equal url_exp, url.url_normalized

    url.update!(url: url_str+"///")
    assert_equal url_str, url.url
    assert_equal url_exp, url.url_normalized

    url.update!(url: url_str+"/?#")
    assert_equal url_str, url.url
    assert_equal url_exp, url.url_normalized

    url.update!(url: url_str+"/a///#")
    assert_equal url_str+"/a/", url.url
    assert_equal url_exp+"/a/", url.url_normalized

    url.update!(url: url_str.sub(%r@/abc@, "////?#"))  # "....com////?#"
    exp = url_str.sub(%r@/abc@, "")
    assert_equal exp,          url.url
    assert_equal exp.downcase.sub(%r@^https://@, ""), url.url_normalized
  end

  test "before_validation to url" do
    ["abc.x/345", "http://localhost"].each do |urlin|
      url = Url.initialize_basic(url: urlin)
      refute url.valid?, "URL=#{urlin} should be invalid, but..."
    end

    urlin = "abc.DEF.com"
    url = Url.create_basic!(url: urlin)
    assert_equal "https://"+urlin, url.url

    url.update!(url:     urlin+"/")
    assert_equal "https://"+urlin, url.url

    url.update!(url:     urlin+"///")
    assert_equal "https://"+urlin, url.url

    url.update!(url:     urlin+"/?")
    assert_equal "https://"+urlin, url.url

    url.update!(url:     urlin+"/#")
    assert_equal "https://"+urlin, url.url

    url.update!(url:     urlin+"/a///")
    assert_equal "https://"+urlin+"/a/", url.url

    url.update!(url:     urlin+"/a?")
    assert_equal "https://"+urlin+"/a", url.url

    url.update!(url:     urlin+"/a#")
    assert_equal "https://"+urlin+"/a", url.url

    url.update!(url:     urlin+"/a?#")
    assert_equal "https://"+urlin+"/a", url.url

    url.update!(url:     urlin+"/a?q=#")
    assert_equal "https://"+urlin+"/a?q=", url.url

    url.update!(url: "WWW."+urlin)
    assert_equal "https://WWW."+urlin, url.url, "should not be downcased with 'www.', but..."
  end

  test "associations" do
    url = urls(:one)
    assert(dt=url.domain_title)
    assert dt.domains.exists?
    assert dt.domains.include?(url.domain)
    assert_equal dt.site_category, url.site_category
  end

  test "self.find_or_create_url_from_str" do
    # The part below is repeated twice, hence a method.
    def mytest_url_dom_dt(url, urlstr, s1, s2, nth, msg)  # nth means n-th call.
      dom = url.domain
      dt  = url.domain_title

      refute url.errors.any?
      refute url.new_record?
      assert_equal "https://"+urlstr.sub(%r@^https://@, ""), url.url, "Failed in #{nth.ordinalize} call (#{msg})..."
      assert_equal s1+s2, url.url_normalized, "url_normalized should be decoded always, but..."

      assert_equal 1, url.translations.count

      assert_equal 1, dt.translations.count
      tra = dt.translations.first
      assert_equal s1.sub(/^www./i, ""), tra.title, "Translation title of DomainTitle should be decoded always, but..."
      assert_equal "ja", tra.langcode

      assert_match(/^[a-z.お名前]+$/, dom.domain, 'should be downcased, but...')
    end

    ## decoded input
    urlstr = "WWW."+(s1="お名前.com")+":8080"+(s2="/some/path?q=日本語&r=国&w=ABC#zy")
    url = Url.find_or_create_url_from_str(urlstr)
    mytest_url_dom_dt(url, urlstr, s1, s2, 1, "No scheme, with 'WWW.'")
    tra = url.translations.first
    assert_equal urlstr.sub(%r@^www\.+@i, "").sub(%r@^([^:/]+)(?::\d+)?(/|$)@, '\1\2'), tra.title
    assert_equal "ja",   tra.langcode

    ## encoded input
    encoded = Addressable::URI.encode("https://"+urlstr)
    url.update!(url: encoded)
    mytest_url_dom_dt(url, encoded, s1, s2, 2, "Encoded with scheme")
    tra = url.translations.first
    assert_equal urlstr.sub(%r@^www\.+@i, "").sub(%r@^([^:/]+)(?::\d+)?(/|$)@, '\1\2'), tra.title, "Translation title of Url should be decoded always, but..."
    assert_equal "ja",   tra.langcode
  end


  test "polymorphic-relations" do
    arclasses = [Artist, Channel, Event, EventGroup, HaramiVid, Music, Place]
    equation = arclasses.map{|i| i.name+".count*100000"}.join(" + ")+' + DomainTitle.count*10000 + Domain.count*1000 + Anchoring.count*100 + Translation.count*10 + Url.count'

    url1 = urls(:one)
    refute_includes url1.translations.to_sql, "anchor"  # this happened when has_many is doubly defined for Translation
    assert url1.translations.exists?
    assert_equal 1, url1.anchorings.count
    assert_includes arclasses, (parent1=url1.anchoring_parents.first).class
    assert_equal 1, parent1.translations.count

    defurl="example.com/new-poly/"
    arclasses.each do |model|
      url = nil
      assert_difference('Translation.count*10 + Url.count', 11){
        url = Url.create_basic!(title: "new-#{__method__}", langcode: "en", url: defurl, domain: url1.domain)
      }
      metho = model.name.underscore.pluralize
      refute url.anchorings.exists?
      refute url.send(metho).exists?
      assert_equal "https://"+defurl, url.reload.url  # test of before_validation add_scheme_to_url

      tit = "#{metho}-test"
      record = model.create_basic!(title: tit, langcode: "en")
      anchor = nil

      # test of creation Anchoring and deletion of Url
      assert_difference('Anchoring.count'){
        anchor = record.add_url(url)  # defined in anchorable.rb
      }
      refute anchor.errors.any?
      [url, record].each do |em|
        assert_equal 1, em.anchorings.count
      end
      assert_equal 1, url.send(metho).count
      assert_equal 1, record.urls.count

      assert_difference(equation, -111){
        url.destroy
      }
      refute Anchoring.exists?(anchor.id), "should have been cascade-destroyed, but..."

      # test of creation Anchoring and Url and deletion of Url
      urlstr = (tit+defurl).gsub(/_/, "")  # "_" is an invalid domain name?
      assert_difference(equation, 11121, "creation Uri fails for #{model.name}..."){
        anchor = record.create_assign_url(urlstr)  # defined in anchorable.rb
        refute anchor.errors.any?, "creation Uri fails for #{model.name} urlstr=#{urlstr.inspect}... errors="+anchor.errors.full_messages.inspect
      }
      assert_equal 1, record.anchorings.count  # "record" should have been already reset (reloaded)
      assert_equal 1, record.urls.count

      url = record.urls.first
      assert_equal 1, url.anchorings.count
      assert_equal 1, url.send(metho).count

      next if EventGroup == model  # destroying EvengGroup is tricky?  So, skippint it for now...

      assert_difference(equation, -100110, "wrong numbers after #{model.name} is destroyed..."){
        record.destroy
      }
      refute Anchoring.exists?(anchor.id), "should have been cascade-destroyed after #{model.name} is destroyed, but..."
    end

    assert_difference(equation, -111, "Destroying Url should not destroy its parent Anchorable (Channel in this case)"){  # p parent1.class  #=> Channel
      url1.destroy
    }
  end
end
