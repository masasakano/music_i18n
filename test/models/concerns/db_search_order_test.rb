# coding: utf-8

require 'test_helper'

class ConcernsDbSearchOrderTest < ActiveSupport::TestCase
  setup do
    # Without this, current_user may(!) exist if you run Controller or Integration tests at the same time.
    ModuleWhodunnit.whodunnit = nil
  end

  test "Translation.find_all_by_affinity and Translation.find_all_best_matches" do
    records = {}
    tras    = {}
    kwd_exact = "test 333 Dayo"  # Should have one exact match and zero more-ambiguous matches
    assert_nil  Translation.find_by(title: kwd_exact), "sanity check"

    # Helper to get Translation for a new Sex
    set_tras = ->(tras, ark) {
      [ark].flatten.each do |k|
        tras[k] = records[k].best_translation
      end
    }

    records[:s13] = _create_new_sex(title: "dummy13",  alt_title: "", romaji: kwd_exact, langcode: "ja", note: "13")  # created before records[:s11]
    records[:s12] = _create_new_sex(title: "dummy12",  alt_title: kwd_exact.capitalize, romaji: "", langcode: "ja", note: "12")  # created before records[:s11]
    records[:s11] = _create_new_sex(title: kwd_exact,  alt_title: "", romaji: "", langcode: "fr", note: "11")  # only French one (for a test of a given Relation)
    set_tras.call(tras, [:s11, :s12, :s13])

    cols = %i(title alt_title romaji)  # order matters
    kwd = kwd_exact

    rela = Translation.find_all_by_affinity( :title, kwd, order_or_where: :both, upto: :exact)
    rel2 = Translation.find_all_best_matches(:title, kwd, parent: nil, upto: :exact)
    exp = [tras[:s11].id]
    assert_equal exp, rela.ids, "SQL="+rela.to_sql
       # "SQL-core="+Translation.find_all_by_affinity(:title, kwd, order_or_where: :both, upto: :exact, debug_return_content_sql: true).join("\n")
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity(:title, kwd, order_or_where: :both)
    assert_includes rela.to_sql.downcase, "where"
    assert_includes rela.to_sql.downcase, "order"
    rela = Translation.find_all_by_affinity(:title, kwd, order_or_where: :where)
    assert_includes rela.to_sql.downcase, "where"
    refute_includes rela.to_sql.downcase, "order"
    rela = Translation.find_all_by_affinity(:title, kwd, order_or_where: :order)
    refute_includes rela.to_sql.downcase, "where"
    assert_includes rela.to_sql.downcase, "order"

    rela_base = Translation.where(translatable_type: "Sex")
    rela = Translation.find_all_by_affinity( :title, kwd, order_or_where: :where, parent: rela_base)
    rel2 = Translation.find_all_best_matches(:title, kwd, parent: rela_base)
    exp = [tras[:s11].id]
    assert_equal exp, rela.ids, "Option parent somehow does not work..."  # "parent" option shoud not cause an error at least.
    assert_equal exp, rel2.ids

    t_alias = "tra"
    sql = "INNER JOIN translations #{t_alias} ON tra.translatable_type = 'Sex' AND tra.translatable_id = sexes.id"
    rela = Translation.find_all_by_affinity( :title, kwd, order_or_where: :where, parent: Sex.joins(sql), t_alias: t_alias)
    rel2 = Translation.find_all_best_matches(:title, kwd, parent: Sex.joins(sql), t_alias: t_alias)
    exp = [records[:s11].id]
    assert_equal exp, rela.ids, "Option t_alias somehow does not work...: "+rela.to_sql
    assert_equal exp, rel2.ids

    prl11 = PlayRole.create_basic!(title: "dummy-PR", alt_ruby: kwd_exact, langcode: "fr", note: "PlayRole", mname: "test_prl11", weight: 1234567) # unique mname and weight are mandatory.
    tra_prl11 = prl11.best_translation
    rela = Translation.find_all_by_affinity( [:alt_ruby, :title], kwd, order_or_where: :both)  # NOTE: the order of [:alt_ruby, :title] (!!)
    rel2 = Translation.find_all_best_matches([:alt_ruby, :title], kwd)
    assert_equal 2, rela.count
    exp = [tra_prl11.id, tras[:s11].id]
    assert_equal exp, rela.ids, "sanity check"  # Translation for PlayRole of alt_ruby should come first (see the line above)
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity( [:alt_ruby, :title], kwd, order_or_where: :both, parent: rela_base)
    rel2 = Translation.find_all_best_matches([:alt_ruby, :title], kwd,                        parent: rela_base)
    exp = [tras[:s11].id]
    assert_equal exp, rela.ids, "Option parent is somehow ignored..."  # "parent" option is definitly working.
    assert_equal exp, rel2.ids

    ### From now on, it is limited to Translation-s for Sex

    def_opts_min = {parent: Translation.where(translatable_type: 'Sex')}
    def_opts = def_opts_min.merge({order_or_where: :both})

    kwd = kwd_exact.capitalize  # "TEST 333 Dayo"  # NOT exact, but Case-insensitive match
    rela = Translation.find_all_by_affinity( :title, kwd, upto: :exact, **def_opts)
    rel2 = Translation.find_all_best_matches(:title, kwd, upto: :exact, **def_opts_min)
    assert_empty  rela.ids
    assert_empty  rel2.ids

    rela = Translation.find_all_by_affinity( :title, kwd, upto: :case_insensitive, **def_opts)
    rel2 = Translation.find_all_best_matches(:title, kwd, upto: :case_insensitive, **def_opts_min)
    exp = [tras[:s11].id]
    assert_equal exp, rela.ids
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity( :title, kwd, upto: nil, **def_opts)
    rel2 = Translation.find_all_best_matches(:title, kwd, upto: nil, **def_opts_min)
    assert_equal exp, rela.ids
    assert_equal exp, rel2.ids

    ["TEST333Dayo", "TE〜ST — - 333-Dayo"].each do |kwd| # Space-insensitive exact match, Space-insensitive exact match (also about a dash/hyphen/mdash)
      rela = Translation.find_all_by_affinity( :title, kwd, upto: :case_insensitive, **def_opts)
      rel2 = Translation.find_all_best_matches(:title, kwd, upto: :case_insensitive, **def_opts_min)
      assert_empty  rela.ids
      assert_empty  rel2.ids

      rela = Translation.find_all_by_affinity( :title, kwd, upto: :space_insensitive_exact, **def_opts)
      rel2 = Translation.find_all_best_matches(:title, kwd, upto: :space_insensitive_exact, **def_opts_min)
      exp = [tras[:s11].id]
      assert_equal exp, rela.ids
      assert_equal exp, rel2.ids
    end
#debugger

    kwd = " ST33 3Day " # Space-insensitive partial match (also about a dash/hyphen/mdash)
    rela = Translation.find_all_by_affinity( :title, kwd, upto: :case_insensitive, **def_opts)
    rel2 = Translation.find_all_best_matches(:title, kwd, upto: :case_insensitive, **def_opts_min)
    assert_empty  rela.ids
    assert_empty  rel2.ids

    rela = Translation.find_all_by_affinity( :title, kwd, upto: :space_insensitive_exact, **def_opts)
    rel2 = Translation.find_all_best_matches(:title, kwd, upto: :space_insensitive_exact, **def_opts_min)
    assert_empty  rela.ids
    assert_empty  rel2.ids

    exp = [tras[:s11].id]
    rela = Translation.find_all_by_affinity( :title, kwd, upto: :space_insensitive_partial, **def_opts)
    rel2 = Translation.find_all_best_matches(:title, kwd, upto: :space_insensitive_partial, **def_opts_min)
    assert_equal exp, rela.ids
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity( :title, kwd, upto: nil, **def_opts)
    assert_equal exp, rela.ids

    #### Tests with title, alt_title, romaji

    kwd = kwd_exact

    hs = {parent: def_opts[:parent].where(langcode: "ja")}
    opts = def_opts.merge(hs)
    opt2 = def_opts_min.merge(hs)
    rela = Translation.find_all_by_affinity( cols, kwd, upto: :exact, **opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :exact, **opt2)
    exp = [tras[:s13].id]
    assert_equal exp, rela.ids, "romaji should be searched, but...: "+rela.inspect  # langcode restriction
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity( cols, kwd, upto: :exact, **def_opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :exact, **def_opts_min)
    exp = [tras[:s11].id, tras[:s13].id]
    assert_equal tras[:s11].title, tras[:s13].romaji, 'santy check'
    assert_equal exp, rela.ids  # tras[:s12] is Caplitalized, hence not satisfying the condition.
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity( cols, kwd.capitalize, upto: :exact, **def_opts)
    exp = [tras[:s12].id]
    assert_equal exp, rela.ids, "kwd=#{kwd.capitalize.inspect} / tra=#{tras[:s12].inspect}"

    exp = [tras[:s11].id, tras[:s13].id, tras[:s12].id]
    ex2 = [tras[:s11].id, tras[:s13].id]
    rela = Translation.find_all_by_affinity( cols, kwd, upto: :case_insensitive, **def_opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :case_insensitive, **def_opts_min)
    assert_equal exp, rela.ids, "three records should match and be returned in the order of title (exact), romaji (exact), alt_title (case-insensitive), but..."
    assert_equal ex2, rel2.ids, "This should differ from the above, but..."

    ### Testing :optional_article_ilike

    kwd = "The "+kwd_exact
    rela = Translation.find_all_by_affinity( cols, kwd, upto: :exact, **def_opts)
    assert_empty rela

    [:optional_article_ilike, :space_insensitive_exact].each do |upto|
      rela = Translation.find_all_by_affinity( cols, kwd, upto: upto, **def_opts)
      rel2 = Translation.find_all_best_matches(cols, kwd, upto: upto, **def_opts_min)
      exp = [tras[:s11].id, tras[:s12].id, tras[:s13].id]
      refute_empty rela
      assert_equal exp, rela.ids, "three records should match and be returned in the order of title, alt_title, romaji because they all match only at :optional_article_ilike (which is also case-insensitive), but..."
      assert_equal exp, rel2.ids, "the same as above, unlike the test above without 'The'"
    end

    ActiveRecord::Base.transaction(requires_new: true) do
      tras[:s11].update!(title: tras[:s11].title+", The")

      kwd = "The "+kwd_exact
      rela = Translation.find_all_by_affinity( cols, kwd, upto: :exact, **def_opts)
      assert_equal [tras[:s11].id], rela.ids, "'The ' at the head should match that at the tail, but..."

      kwd = kwd_exact

      rela = Translation.find_all_by_affinity( cols, kwd, upto: :exact, **def_opts)
      assert_equal [tras[:s13].id], rela.ids  # :s11 now has "The" while :s13 does NOT. So, :s13 should match

      rela = Translation.find_all_by_affinity( cols, kwd, upto: :case_insensitive, **def_opts)
      exp = [tras[:s13], tras[:s12]].map(&:id)  # :s11 is excluded because of its "The"
      assert_equal exp, rela.ids  # :s11 now has "The", so does not match.

      [:optional_article_ilike, :space_insensitive_exact].each do |upto|
        rela = Translation.find_all_by_affinity( cols, kwd, upto: upto, **def_opts)
        rel2 = Translation.find_all_best_matches(cols, kwd, upto: upto, **def_opts_min)
        exp = [tras[:s13], tras[:s12], tras[:s11]].map(&:id)
        ex2 = [tras[:s13].id]
        assert_equal exp, rela.ids, "all three should match, but..."
        assert_equal ex2, rel2.ids, "Only one of them is the exact match, but..."
      end

      raise ActiveRecord::Rollback, "Force rollback."
    end

    ### Added one with romaji of 1-character less
    records[:s23] = _create_new_sex(title: "dummy-23",  alt_title: "", romaji: kwd_exact.chop, note: "23")
    set_tras.call(tras, [:s23])
    kwd = kwd_exact.chop

    rela = Translation.find_all_by_affinity( cols, kwd, upto: :space_insensitive_exact, **def_opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :space_insensitive_exact, **def_opts_min)
    exp = [tras[:s23].id]
    assert_equal exp, rela.ids  # tras[:s12] is Caplitalized, hence not satisfying the condition.
    assert_equal exp, rel2.ids

    rela = Translation.find_all_by_affinity( cols, kwd, upto: :space_insensitive_partial, **def_opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :space_insensitive_partial, **def_opts_min)
    # print "DEBUG:234: kwd=#{kwd.inspect}: "; pp [tras[:s23], tras[:s11], tras[:s12], tras[:s13]]
    exp = [tras[:s23].id, tras[:s11].id, tras[:s12].id, tras[:s13].id]
    ex2 = [tras[:s23].id]
    assert_equal [[tras[:s23].id, kwd]], Translation.where(romaji: kwd).pluck(:id, :romaji), "sanity-check; only one entry has an exact match"
    assert_equal exp, rela.ids, "s23-romaji should come first because it is the only :space_insensitive_exact match, and the rest follows, but...: "+rela.inspect
    assert_equal ex2, rel2.ids

    ### tests of alt_title with :space_insensitive_exact
    ar = kwd_exact.split 
    kwd = (["— -〜"+ar[0].upcase]+ar[1..-1]).join(" ").chop
    atit = (ar[0..-2]+["〜"+ar[-1].upcase.chop.sub(/(.)(..)/, '\1〜\2')+"— -"]).join(" ")
    assert_equal atit.downcase.gsub(/[\s—〜\-]/, ""), kwd.downcase.gsub(/[\s—〜\-]/, ""), 'sanity check'
    records[:s32] = _create_new_sex(title: nil,  alt_title: atit, romaji: "", note: "32")
    set_tras.call(tras, [:s32])
    rela = Translation.find_all_by_affinity( cols, kwd, upto: :space_insensitive_exact, **def_opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :space_insensitive_exact, **def_opts_min)
    exp = [tras[:s32].id, tras[:s23].id]
    assert_equal exp, rela.ids  # both kwd and records are space-insensitive. alt_title should come first.
    assert_equal exp, rel2.ids

    ### tests of :space_insensitive_forward
    kwdtmp = kwd_exact[1..-1]
    kwd = kwdtmp[0..1]+" "+kwdtmp[2..-1]
    cnt_orig1 = Translation.find_all_by_affinity( cols, kwd, upto: :space_insensitive_partial, **def_opts).count
    cnt_orig2 = Translation.find_all_best_matches(cols, kwd, upto: :space_insensitive_partial, **def_opts_min).count
    assert_operator 1, :<, cnt_orig1
    assert_operator 1, :<, cnt_orig2

    records[:s42] = _create_new_sex(title: nil,  alt_title: kwdtmp.capitalize+" extra-tail", romaji: "", note: "32")  # This is longer than other Translation records, but forward-matches (in a case-insensitive, space-insensitive search)
    trans_s42 = records[:s42].best_translation
    rela = Translation.find_all_by_affinity( cols, kwd, upto: :space_insensitive_partial, **def_opts)
    rel2 = Translation.find_all_best_matches(cols, kwd, upto: :space_insensitive_partial, **def_opts_min)
    assert_equal cnt_orig1+1, rela.count
    assert_equal trans_s42, rela.first  # should be sorted
    assert_equal 1,         rel2.count, "Only 1 matches :space_insensitive_forward, so only that should be returned, but..."
    assert_equal trans_s42, rel2.first

    ### tests of explicit :order_steps
    order_steps = [:exact, :case_insensitive]
    tra = records[:s13].best_translation
    kwd = tra.title.upcase

    act = Translation.find_all_best_matches(cols, kwd, upto: :exact,            order_steps: order_steps, parent: rela_base)
    refute act.exists?
    act = Translation.find_all_best_matches(cols, kwd, upto: :case_insensitive, order_steps: order_steps, parent: rela_base)
    assert_equal tra, act.first
    assert_raises(ArgumentError){
          Translation.find_all_best_matches(cols, kwd, upto: :space_insensitive_forward, order_steps: order_steps, parent: rela_base) }
    act = Translation.find_all_best_matches(cols, kwd, upto: nil,               order_steps: order_steps, parent: rela_base)
    assert_equal tra, act.first
  end

  test "Translation.collated_condition_sql" do
    ini = ["title", "ILIKE", "'abc'"]
    exp = "title COLLATE \"und-x-icu\" ILIKE 'abc'"
    assert_equal exp, Translation.collated_condition_sql(*ini)
    assert_equal exp, Translation.collated_condition_sql( ini)
  end

  test "_kwds_for_affinity_search" do
    raw_kwd = %Q@The Adam's_A%%le "P-ie"@
    hsret = Translation.send(:_kwds_for_affinity_search, raw_kwd, DbSearchOrder::PSQL_MATCH_ORDER_STEPS, DbSearchOrder::PSQL_MATCH_ORDER_STEPS.size)
    arexp = {
      raw: raw_kwd,
      raw_article_tail:        %q@Adam's_A%%le "P-ie", The@,
      quoted_raw:         %q@'The Adam''s_A%%le "P-ie"'@,
      quoted:                 %q@'Adam''s_A%%le "P-ie", The'@,
      quoted_like:            %q@'Adam''s\_A\%\%le "P-ie", The'@,
      no_article:              %q@adam's_a%%le "p-ie"@,
      quoted_no_article_like: %q@'adam''s\_a\%\%le "p-ie"'@,
      truncated_base:          %q@adam's_a%%le"pie"@,
      quoted_truncated_like:  %q@'adam''s\_a\%\%le"pie"'@,
    }

    arexp.each_key do |ek|
      assert_equal arexp[ek], hsret[ek], sprintf("[:%s]: (expected) %s <=> (actual) %s", ek.to_s, arexp[ek], hsret[ek])
    end
  end

  private
    # Returns a new valid Sex
    #
    # @example
    #   sex11 = _create_new_sex(alt_title: "aLe", romaji: "", langcode: "ja", note: "12")
    #
    # @return [Sex]
    def _create_new_sex(langcode: "en", is_orig: nil, iso5218: nil, note: "NONE", **opts)
      @iso5218 ||= 91
      if !iso5218
        loop do
          @iso5218 += 10
          break if !Sex.find_by(iso5218: @iso5218)
        end
      end

      Sex.create_basic!(langcode: langcode, is_orig: is_orig, iso5218: iso5218 || @iso5218, note: note, **opts)  # weight is automatically set.
    end
end

