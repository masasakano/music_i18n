# coding: utf-8

require 'test_helper'

class ConcernsDbSearchOrderTest < ActiveSupport::TestCase
  setup do
    # Without this, current_user may(!) exist if you run Controller or Integration tests at the same time.
    ModuleWhodunnit.whodunnit = nil
  end

  test "Translation.select_regex for ILIKE" do
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

    rela = Translation.search_by_affinity(:title, kwd, order_or_where: :both, upto: :exact)
    assert_equal [tras[:s11].id], rela.ids, "SQL="+rela.to_sql
       # "SQL-core="+Translation.search_by_affinity(:title, kwd, order_or_where: :both, upto: :exact, debug_return_content_sql: true).join("\n")

    rela = Translation.search_by_affinity(:title, kwd, order_or_where: :both)
    assert_includes rela.to_sql.downcase, "where"
    assert_includes rela.to_sql.downcase, "order"
    rela = Translation.search_by_affinity(:title, kwd, order_or_where: :where)
    assert_includes rela.to_sql.downcase, "where"
    refute_includes rela.to_sql.downcase, "order"
    rela = Translation.search_by_affinity(:title, kwd, order_or_where: :order)
    refute_includes rela.to_sql.downcase, "where"
    assert_includes rela.to_sql.downcase, "order"

    rela_base = Translation.where(translatable_type: "Sex")
    rela = Translation.search_by_affinity(:title, kwd, order_or_where: :where, parent: rela_base)
    assert_equal [tras[:s11].id], rela.ids, "Option parent somehow does not work..."  # "parent" option shoud not cause an error at least.

    t_alias = "tra"
    sql = "INNER JOIN translations #{t_alias} ON tra.translatable_type = 'Sex' AND tra.translatable_id = sexes.id"
    rela = Translation.search_by_affinity(:title, kwd, order_or_where: :where, parent: Sex.joins(sql), t_alias: t_alias)
    assert_equal [records[:s11].id], rela.ids, "Option t_alias somehow does not work...: "+rela.to_sql

    prl11 = PlayRole.create_basic!(title: "dummy-PR", alt_ruby: kwd_exact, langcode: "fr", note: "PlayRole", mname: "test_prl11", weight: 1234567) # unique mname and weight are mandatory.
    tra_prl11 = prl11.best_translation
    rela = Translation.search_by_affinity([:alt_ruby, :title], kwd, order_or_where: :both)  # NOTE: the order of [:alt_ruby, :title] (!!)
    assert_equal 2, rela.count
    assert_equal [tra_prl11.id, tras[:s11].id], rela.ids, "sanity check"  # Translation for PlayRole of alt_ruby should come first (see the line above)
    rela = Translation.search_by_affinity([:alt_ruby, :title], kwd, order_or_where: :both, parent: rela_base)
    assert_equal [tras[:s11].id], rela.ids, "Option parent is somehow ignored..."  # "parent" option is definitly working.

    ### From now on, it is limited to Translation-s for Sex

    def_opts_min = {parent: Translation.where(translatable_type: 'Sex')}
    def_opts = def_opts_min.merge({order_or_where: :both})

    kwd = kwd_exact.capitalize  # "TEST 333 Dayo"  # NOT exact, but Case-insensitive match
    rela = Translation.search_by_affinity(:title, kwd, upto: :exact, **def_opts)
    assert_empty  rela.ids

    rela = Translation.search_by_affinity(:title, kwd, upto: :caseInsensitive, **def_opts)
    assert_equal [tras[:s11].id], rela.ids
    rela = Translation.search_by_affinity(:title, kwd, upto: nil, **def_opts)
    assert_equal [tras[:s11].id], rela.ids

    ["TEST333Dayo", "TE〜ST — - 333-Dayo"].each do |kwd| # Space-insensitive exact match, Space-insensitive exact match (also about a dash/hyphen/mdash)
      rela = Translation.search_by_affinity(:title, kwd, upto: :caseInsensitive, **def_opts)
      assert_empty  rela.ids
      rela = Translation.search_by_affinity(:title, kwd, upto: :spaceInsensitiveExact, **def_opts)
      assert_equal [tras[:s11].id], rela.ids
    end

    kwd = " ST33 3Day " # Space-insensitive partial match (also about a dash/hyphen/mdash)
    rela = Translation.search_by_affinity(:title, kwd, upto: :caseInsensitive, **def_opts)
    assert_empty  rela.ids
    rela = Translation.search_by_affinity(:title, kwd, upto: :spaceInsensitiveExact, **def_opts)
    assert_empty  rela.ids
    rela = Translation.search_by_affinity(:title, kwd, upto: :spaceInsensitivePartial, **def_opts)
    assert_equal [tras[:s11].id], rela.ids
    rela = Translation.search_by_affinity(:title, kwd, upto: nil, **def_opts)
    assert_equal [tras[:s11].id], rela.ids

    #### Tests with title, alt_title, romaji

    kwd = kwd_exact

    opts = def_opts.merge({parent: def_opts[:parent].where(langcode: "ja")})
    rela = Translation.search_by_affinity(cols, kwd, upto: :exact, **opts)
    assert_equal [tras[:s13].id], rela.ids, "romaji should be searched, but...: "+rela.inspect  # langcode restriction

    rela = Translation.search_by_affinity(cols, kwd, upto: :exact, **def_opts)
    exp = [tras[:s11].id, tras[:s13].id]
    assert_equal exp, rela.ids  # tras[:s12] is Caplitalized, hence not satisfying the condition.

    rela = Translation.search_by_affinity(cols, kwd.capitalize, upto: :exact, **def_opts)
    exp = [tras[:s12].id]
    assert_equal exp, rela.ids, "kwd=#{kwd.capitalize.inspect} / tra=#{tras[:s12].inspect}"

    rela = Translation.search_by_affinity(cols, kwd, upto: :caseInsensitive, **def_opts)
    exp = [tras[:s11].id, tras[:s13].id, tras[:s12].id]
    assert_equal exp, rela.ids, "three records should match and be returned in the order of title (exact), romaji (exact), alt_title (case-insensitive), but..."

    ### Added one with romaji of 1-character less
    records[:s23] = _create_new_sex(title: "dummy-23",  alt_title: "", romaji: kwd_exact.chop, note: "23")
    set_tras.call(tras, [:s23])
    kwd = kwd_exact.chop

    rela = Translation.search_by_affinity(cols, kwd, upto: :spaceInsensitiveExact, **def_opts)
    exp = [tras[:s23].id]
    assert_equal exp, rela.ids  # tras[:s12] is Caplitalized, hence not satisfying the condition.

    rela = Translation.search_by_affinity(cols, kwd, upto: :spaceInsensitivePartial, **def_opts)
    exp = [tras[:s23].id, tras[:s11].id, tras[:s12].id, tras[:s13].id]
    assert_equal exp, rela.ids, "s23-romaji should come first because it is the only :spaceInsensitiveExact match, and the rest follows, but...: "+rela.inspect

    ### tests of alt_title with :spaceInsensitiveExact
    ar = kwd_exact.split 
    kwd = (["— -〜"+ar[0].upcase]+ar[1..-1]).join(" ").chop
    atit = (ar[0..-2]+["〜"+ar[-1].upcase.chop.sub(/(.)(..)/, '\1〜\2')+"— -"]).join(" ")
    assert_equal atit.downcase.gsub(/[\s—〜\-]/, ""), kwd.downcase.gsub(/[\s—〜\-]/, ""), 'sanity check'
    records[:s32] = _create_new_sex(title: nil,  alt_title: atit, romaji: "", note: "32")
    set_tras.call(tras, [:s32])

    rela = Translation.search_by_affinity(cols, kwd, upto: :spaceInsensitiveExact, **def_opts)
    exp = [tras[:s32].id, tras[:s23].id]
    assert_equal exp, rela.ids  # both kwd and records are space-insensitive. alt_title should come first.

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

