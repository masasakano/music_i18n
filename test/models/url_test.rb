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


    #   one:
    #   url: "https://www.mydomain.org/abc"
    #   url_normalized: "www.mydomain.org/abc"
    #   domain_title: one
    #   url_langcode: en
    #   weight: 100.5
    #   published_date: 2025-04-01
    #   last_confirmed_date: 2025-04-15
    #   create_user: user_editor
    #   update_user: user_moderator
    #   note: UrlMyTextOne
    #   memo_editor: UrlMyMemoOne
    # 
    # two:
    #   url: "https://www.mydomain.org:80/def?myquery=5&other=6"
    #   url_normalized: "mydomain.org/abc?myquery=5&other=6"
    #   domain_title: two
    #   url_langcode: 
    #   weight: 108.5
    #   published_date: 2025-04-02
    #   last_confirmed_date: 2025-04-12
    #   create_user: user_editor_general_ja
    #   update_user: user_moderator
    #   note: UrlMyNoteOne
    #   memo_editor: UrlMyMemoTwo

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
  end

  test "normalized url" do
    dt = DomainTitle.unknown
    pri_domain_str = dt.primary_domain.domain
    assert pri_domain_str, 'sanity check'
    url_str = "https://"+pri_domain_str.sub(%r@^(https?://)?(www\.)@, "").capitalize.sub(/\.com/, ".COM")+"/abc"

    url_obj = URI.parse(url_str)
  end

  test "associations" do
    url = urls(:one)
    assert(dt=url.domain_title)
    assert dt.domains.exists?
    assert dt.domains.include?(url.domain)
    assert_equal dt.site_category, url.site_category
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
