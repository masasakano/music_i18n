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

  test "self.find_url_from_str" do
    url1str = "http://abc.com:80/?#"
    sc1 = site_categories(:site_category_media)
    url1 = Url.create_basic!(url: url1str, note: "url1")
    dt1  = url1.domain_title
    dt1.update!(site_category_id: sc1.id)
    url1.reload

    assert_nil         Url.find_url_from_str("my.non-existent.com")
    assert_equal url1, Url.find_url_from_str(url1str)
    assert_equal url1, Url.find_url_from_str("abc.com")
    assert_equal url1, Url.find_url_from_str("https://abc.com:443")
    assert_equal url1, Url.find_url_from_str("https://abc.com:443///")
    assert_equal url1, Url.find_url_from_str("abc.com///#")
    assert_equal url1, Url.find_url_from_str("abc.com//?")
    assert_nil         Url.find_url_from_str("abc.com/xxx?#")
    assert_nil         Url.find_url_from_str("abc.com//xxx")
  end

  test "self.create_url_from_str" do
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
    url = Url.create_url_from_str(urlstr)
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

  test "self.create_url_from_str failing" do
    assert_raises(HaramiMusicI18n::Domains::CascadeSaveError){
      Domain.find_or_create_domain_by_url!("日本語のダメなヤツ") }
    url = Url.create_url_from_str("日本語のダメなヤツ")
    assert url.errors.any?
    assert_includes url.errors.full_messages.join(" "), "日本語のダメなヤツ"

    urlstr = "https://this.some-non-exitent.org/abc"
    url1 = Url.create_url_from_str(urlstr)
    assert url1.valid?
    url2 = Url.create_url_from_str(urlstr)
    refute url2.valid?
  end

  test "update translation externally" do
    url1 = urls(:one)
    assert_equal 1, url1.translations.count
    assert url1.update_best_translation("Something")

    url1.reload
    assert_equal "Something", url1.title

    assert url1.update_best_translation("何か")
    url1.reload
    tra = url1.best_translation
    assert_equal "何か", tra.title
    assert_equal "ja",   tra.langcode

    url1.translations << Translation.new(title: "another title", langcode: "fr", is_orig: false)  # very different language
    refute url1.update_best_translation("third attempt fails")
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

  #########
  test "Anchoring. and Url.find_or_create_multi_from_note" do
    assert_raise(ArgumentError){
      Url.find_multi_from_note("strange", 5) }
    assert_raise(HaramiMusicI18n::Urls::NotAnchorableError){
      Url.find_multi_from_note(User.first) }
    assert_raise(ActiveRecord::RecordNotFound){
      Url.find_multi_from_note(Artist.name, -1) }

    chronicle = "https://nannohi-db.blog.jp/archives/8522599.html"
    exp_calc = 'DomainTitle.count*1000 + Domain.count*1000 + Translation.count*100 + Url.count*10 + Anchoring.count'
    wiki_lang="ja"
    wiki_name="ニセコ"
    wiki_ja = "https://#{wiki_lang}.wikipedia.org/wiki/"+wiki_name
    wiki_ja_encoded = "https://ja.wikipedia.org/wiki/%E3%83%8B%E3%82%BB%E3%82%B3"  # ニセコ

    url_unk = Url.unknown
    url_unk_norm = url_unk.url_normalized  # "example.com"
    assert_equal "example.com", url_unk_norm, 'sanity check'

    url_unk_tit = url_unk.title(langcode: "en")
    tra_best = Translation.sort(url_unk.best_translations.values).first
    url_unk.translations.each do |tra|
      next if tra_best == tra
      tra.destroy
    end
    url_unk.translations.reset
    assert_equal 1, url_unk.translations.count
    assert_equal url_unk_tit,      url_unk.title
    refute_equal 'Exapmle Domain', url_unk.title, 'test fixtures'  # title in fixtures should be "example.com"

    plas = (1..2).map{ |i| Place.create_basic!(title: "new#{i} place url", langcode: "en")}
    notes = []

    urlstr = "http://example.com"
    notes[0] = sprintf('%s bc <a href="http://abc.com/kkk"> de </a> fg [another](https://xxx.org/mmm) hi j.k  <%s>', urlstr, urlstr)

    url_imported_core = "to-be-imported.com"
    url_imported_norms = [url_imported_core+"/head?q=x&r=y#st", url_imported_core]
    notes[1] = sprintf("%s %s %s a link %s hi %s",
                       "www."+url_imported_norms[0], wiki_ja, chronicle, notes[0], "https://"+url_imported_norms[1])
                      # with "www." but no scheme,                         with scheme but no www.

    plas.each_with_index do |epla, i|
      epla.update!(note: notes[i])
    end

    ######### Find-only: Url.find_multi_from_note()

    exps = []
    exps[0] = [[urlstr]*2, [Url.unknown]*2]  # [[Array<String(Processed), String(Original)>, Array<Url|String>], [...]]
    ar2 = ModuleUrlUtil.extract_url_like_string_and_raws(notes[0])
    assert_includes ar2.map(&:first), urlstr, 'sanity check'
    assert_no_difference(exp_calc){
      assert_equal exps[0][1], (urls=Url.find_multi_from_note(plas[0])) # notes[0]
      urls.each do |url|
        assert url.was_found? if respond_to?(:reload)
        assert exps[0][0][1], url.original_path  # == urlstr
      end
    }

    exps[1] = [["https://www."+url_imported_norms[0],
                [wiki_ja, chronicle].map{|i| ModuleUrlUtil.url_prepended_with_scheme(i)},
                ["http://"+url_unk_norm]*2,
                "https://"+url_imported_norms[1]
               ].flatten,
               []]
    exps[1][1] = [url_imported_norms[0],
                  [ModuleUrlUtil.url_prepended_with_scheme(wiki_ja), wiki_ja],
                  [ModuleUrlUtil.url_prepended_with_scheme(chronicle), chronicle],
                  url_unk,
                  url_unk,
                  url_imported_norms[1]]

    ar2 = ModuleUrlUtil.extract_url_like_string_and_raws(notes[1])
    assert_equal exps[1][0],  ar2.map(&:first)  # 6-elements Array; thouse in <A> tags and markdown are not picked up.

    [0, 1].each do |i|
      exps[1][i].pop    ### NOTE: url_imported_* will be ignored in this test!
      exps[1][i].shift  ###
    end

    assert_no_difference(exp_calc){
      assert_equal exps[1][1], (urls=Url.find_multi_from_note(plas[1]))  # notes[1]
      urls.each do |url|
        if url.respond_to?(:reload)
          assert url.was_found?
          assert exps[1][0][1], url.original_path
        else
          assert exps[1][0][1], url[1]  # sanity check
        end
      end
    }

    ## reverse (nothing happens because there is no Anchoring)
    _confirm_no_change_in_note(plas[1], wiki_ja)

    ######### Create Url: Url.find_or_create_multi_from_note()

    urls = []
    exp_urls = []

    def _test_example_com(exp_calc, fetch_h1, plas, notes)
      urls = []
      assert_difference(exp_calc, 0){
        urls = Url.find_or_create_multi_from_note(plas[0], notes[0], fetch_h1: fetch_h1)
      }
      assert_equal 1,       urls.size, "urls=#{urls.inspect}"
      assert  urls.all?{|eu| eu.original_path.present?}
      assert_equal Url.unknown, (url=urls.first)
      refute  url.errors.any?
      refute  url.was_created?
      refute  url.domain_created?
      url
    end

    ### DB Transaction (to test a fresh create later)
    ActiveRecord::Base.transaction(requires_new: true) do

      ######### Create Url-s: Url.find_or_create_multi_from_note()
      ## First sample
      # 1st
      url = _test_example_com(exp_calc, false, plas, notes)
      assert_equal url_unk_tit, url.reload.title
      refute  url.was_created?
      refute  url.domain_created?

      # 2nd
      assert_equal 1, url_unk.translations.count, 'sanity check'
      url = _test_example_com(exp_calc, true, plas, notes)
      url.translations.reset
      assert_equal url_unk_tit, url.reload.title  # fetch_h1 has no effect on an existing Url


      ## Second sample

      assert_difference(exp_calc, 220){
        urls = Url.find_or_create_multi_from_note(plas[1], notes[1], fetch_h1: false)
      }
      exp_urls = urls  # used in the Anchoring tests later

      assert_equal 3,       urls.size  # first and last are ignored.
      assert_equal url_unk, urls[0], "Urls=#{urls.inspect}"  # i=0 because the Array is reversed and the original last one is ignored (filtered out)

      url4chronicle, url4wiki = urls[1..2]  # the order is reversed from the appearing order in note

      # url4importeds = [urls[0], urls[4]]
      # [0, 1].each do |i|
      #   assert_equal url_imported_norms[i], url4importeds.url_normalized
      # end
      # assert_equal "https://www."+url_imported_norms[0], url4importeds.url
      # assert  url4importeds.all?(&:was_created?)
      # assert  url4importeds.all?(&:domain_created?)
      # assert_equal url4importeds[0].site_category, assert_equal url4importeds[1].site_category

      ## wiki
      assert_equal wiki_ja_encoded,  url4wiki.url
      assert_equal wiki_lang,  url4wiki.orig_langcode.to_s
      assert_equal site_categories(:site_category_wikipedia), url4wiki.site_category
      trans = url4wiki.orig_translation
      assert_equal wiki_name,  trans.title, "#{_get_caller_info_message(prefix: true)} Wiki-name is wrong... #{[url4wiki, wiki_name, wiki_lang].inspect}"
      assert_equal wiki_lang,  trans.langcode

      assert_includes url4wiki.title,    trans.title, 'sanity check'
      assert_includes url4wiki.domain_title.title(langcode: "en"), 'Wikipedia'

      ## chronicle
      assert_equal chronicle, url4chronicle.url
      assert_equal "ja",      url4chronicle.url_langcode.to_s
      assert_equal site_categories(:site_category_chronicle), url4chronicle.site_category

      ## reverse (nothing happens because there is no Anchoring)
      _confirm_no_change_in_note(plas[1], wiki_ja)

      ######### Create Anchoring-s: Anchoring.find_or_create_multi_from_note()
      # First example

      ancs = []
      assert_difference(exp_calc, 1){
        ancs = Anchoring.find_or_create_multi_from_note(plas[0], notes[0], fetch_h1: false)
      }
      assert_equal 1,       ancs.size
      anc = ancs.first
      assert_equal url_unk,        anc.url
      assert_equal plas[0],        anc.anchorable
      assert_equal Anchoring.last, anc
      assert  anc.was_created?
      refute  anc.url_created?
      refute  anc.domain_created?

      # Second example
      ancs = []
      assert_difference(exp_calc, 3){
        # Everything (Urls, Domains, DomainTitles) should have been created but Anchoring.
#debugger
        ancs = Anchoring.find_or_create_multi_from_note(plas[1], notes[1], remove_from_note: false, fetch_h1: false)
      }
      assert_equal 3,       ancs.size    # first and last are ignored.
      assert ancs.all?{|ea| plas[1] == ea.anchorable }
      assert_equal url_unk, ancs[0].url  # b/c first is ignored.
      ancs.each_with_index do |anc, i|
        assert_equal exp_urls[i], anc.url
      end

      assert  ancs.all?(&:was_created?)
      refute  ancs[0].url_created?
      # rerute  ancs[0].domain_created?  # When url_created? is false, domain_created? may be undefined.

      new_ancs = ancs.values_at(1,2)  # all but Url.unknown
      refute  new_ancs.all?(&:url_created?), (1..2).map{|i| sprintf("ancs[%d]: %s", i, [ancs[i].url_created?, ancs[i].url].inspect)}.join("\n")
      refute  new_ancs.all?(&:domain_created?)
      assert  ancs.all?{|ea| ea.notice_messages.blank?}

      ## reverse (nothing happens because note still contains URL-like Strings)
      _confirm_no_change_in_note(plas[1], wiki_ja)

      ######### Attempto to re-Create Anchoring (should raise no errors): Anchoring.find_or_create_multi_from_note()
      # Both

      [0,1].each do |i|
        assert_difference(exp_calc, 0){
          ancs = Anchoring.find_or_create_multi_from_note(plas[i], notes[i], remove_from_note: false, fetch_h1: false)
        }
        refute  ancs.all?(&:was_created?)
        # refute  ancs.all?(&:url_created?)    # When Anchoring was_found?, Url should be just found, not created.
        # refute  ancs.all?(&:domain_created?)
        assert  ancs.all?{|ea| ea.notice_messages.blank?}
      end

      ### checking presence of URL-strings remaining in Place#note
      [0,1].each do |i|
        assert_match(/#{Regexp.quote(exps[i][0][1])}/, plas[i].note)
      end
      ## Below, the values should be written with exps[...]; However, I have messed up with exps and the values are not what I intended. It is far too messy to understand now... (I should have written it with Hash, as opposed to multi-layered Array.)
      assert_match(/#{Regexp.quote(wiki_ja)}/,   plas[1].note)
      assert_match(/#{Regexp.quote(chronicle)}/, plas[1].note)
      excom = Regexp.quote(exps[0][0][1])  # http://example.com  # This should really be:  exps[1][SOMETHING]
      assert_match(/#{excom}/,           plas[1].note)
      assert_match(/#{excom}.+#{excom}/, plas[1].note)

      raise ActiveRecord::Rollback, "Force rollback."
    end  ## ActiveRecord::Base.transaction(requires_new: true) do

    ############
    ## Create Anchoring from scratch (not trying the first example because the second one anyway includes a case of creating Anchoring for Url.unknown)

    plas.each do |pla|
      pla.anchorings.reset  ## Essential.  Otherwise, place.save would return nil because of "Anchorings is invalid" ALTHOUGH place.save itself succeeds, weirdly!!
    end

    ancs = []

    t_before = Time.now
    assert_difference(exp_calc, 223){

      ancs = Anchoring.find_or_create_multi_from_note(plas[1], notes[1], remove_from_note: true, fetch_h1: false)
    }

    last_url = Url.order(:created_at).last
    assert_operator t_before.utc, :<=, last_url.created_at.utc
    expected_scs = [:site_category_chronicle, :site_category_wikipedia].map{|i| site_categories(i)}
    assert_includes expected_scs, last_url.site_category  # The SiteCategory of the last-created Url must be either Chronicle or Wikipedia

    assert_equal 3,       ancs.size    # first and last are ignored.
    assert ancs.all?{|ea| plas[1] == ea.anchorable }
    assert_equal url_unk, ancs[0].url  # b/c first is ignored.
    ancs.each_with_index do |anc, i|
      assert_equal exp_urls[i].url, anc.url.url  # exp_urls[i] has been destroyed (by DB rollback), so only their contents are comparable.
    end

    assert  ancs.all?(&:was_created?)
    refute  ancs[0].url_created?
    # rerute  ancs[0].domain_created?  # When url_created? is false, domain_created? may be undefined.

    new_ancs = ancs.values_at(1,2)  # all but Url.unknown
    assert  new_ancs.all?(&:url_created?), (1..2).map{|i| sprintf("ancs[%d]: %s", i, [ancs[i].url_created?, ancs[i].url].inspect)}.join("\n")
    refute  new_ancs.all?(&:domain_created?), "Wikipedia/Chronicle Domains have been long defined."

    assert  ancs.all?{|ea| ea.notice_messages.blank?}, "Anchoring#notice_messages: \n"+ancs.map.with_index{|ea, i| [i, ea.notice_messages].inspect}.join("\n")

    ### checking if URL-strings have been removed from Place#note
    plas[1].reload
    refute_match(/#{Regexp.quote(wiki_ja)}/,   plas[1].note)
    refute_match(/#{Regexp.quote(chronicle)}/, plas[1].note)
    excom = Regexp.quote(exps[0][0][1])  # http://example.com  # This should really be:  exps[1][SOMETHING]
    assert_match(/#{excom}/,           plas[1].note)  # Original had two "example.com" and only one of them should have been removed (because duplicated removals are deliberately avoided in the algorithm.).
    refute_match(/#{excom}.+#{excom}/, plas[1].note)

    ## reverse action (to export Urls to note)
    orig_note = plas[1].note.dup  # .dup is essential
    refute_includes plas[1].note, wiki_ja
    exported_ancs = Anchoring.export_urls_to_note(plas[1], bang: false)
    assert_equal 2, exported_ancs.size, "should be Wiki and Harami-Chronicle, not including example.com (because the Url still exists in note as only one of them had been removed out of two), but..."
    refute_equal orig_note, plas[1].reload.note
    assert_includes plas[1].note, wiki_ja
  end  # test "Anchoring. and Url.find_or_create_multi_from_note" do

  private

    # "reverse"-action should have done nothing on anchorable#note (for whatever reason)
    #
    # @param kwd_url [String] e.g., "https://ja.wikipedia.org/ニセコ" which should exist in Note
    def _confirm_no_change_in_note(anchorable, kwd_url)
      orig_note = anchorable.note.dup  # .dup is essential
      assert_empty Anchoring.export_urls_to_note(anchorable, bang: false)
      assert_equal orig_note, anchorable.reload.note
      assert_includes anchorable.note, kwd_url
    end

end
