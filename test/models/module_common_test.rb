# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
  include ModuleCommon

  test "date2text" do
    assert_equal '——年8月——日', date2text(nil,  8, "", langcode: "ja")
    assert_equal '2001-08-??', date2text(2001, 8, "", langcode: "en")
    assert_match(/\bAugust\b/, date2text(nil,  8, 28, langcode: "en"))
    assert_match(/\bAugust\b/, date2text(nil,  8, "", langcode: "en"))
  end

  test "zenkaku_to_ascii with emojis" do
    # Without emojis
    instr = '寝落ち用ＢＧＭ弾きます【高音質】【ハラミナイト】！!!！！'
    sout = zenkaku_to_ascii(instr, Z: 1)
    assert sout.include?('【高音質】【ハラミナイト】')
    assert sout.include?('BGM')
    assert sout.include?('!!!!!')

    # With emojis
    instr = '【最終回】寝落ち用BGM弾きます🐏🌙【高音質】【ハラミナイト】'
    sout = zenkaku_to_ascii(instr, Z: 1)
    assert sout.include?('【高音質】【ハラミナイト】')
  end

  test "preprocess_space_zenkaku" do
    instr = "\u3000\n寝落ち用ＢＧＭ弾き\n\n\u3000 ます【高音質】（ハラミナイト）！!!！！\u3000\n\n"
    exp1 = "寝落ち用BGM弾き ます【高音質】(ハラミナイト)!!!!!"
    exp2 = "寝落ち用BGM弾き\n\n ます【高音質】(ハラミナイト)!!!!!"
      ## Explanation of {convert_spaces: false} (Default in preprocess_space_zenkaku but NOT in SlimString):
      ## 1. Stripped both the head and tail of the entire String (not each line).
      ## 2. Newlines in between remain (no truncation, either).
      ## 3. Multiple space-likes in between trimmed into one (but not stripped even if it is at the head or tail of a line).
    assert_equal exp1, preprocess_space_zenkaku(instr)
    assert_equal exp2, preprocess_space_zenkaku(instr, **(COMMON_DEF_SLIM_OPTIONS.merge({convert_spaces: false})))
    assert_nil   preprocess_space_zenkaku(nil)
    assert_equal 5,    preprocess_space_zenkaku(5)
    assert_equal true, preprocess_space_zenkaku(true)
    assert_equal({x: 'abc'}, preprocess_space_zenkaku({x: 'abc'}))
    assert_equal ['abc'],    preprocess_space_zenkaku(['abc'])

    # "FULLWIDTH TILDE" => "wave dash"
    s_tilde = "あsjis(\uff5e) jis(\u301c)"  # SJIS(\uFF5E)(～)(UTF8: "FULLWIDTH TILDE") and JIS(\u301C)(〜)(UTF8: "wave dash")
    refute_equal s_tilde, preprocess_space_zenkaku(s_tilde)
    s = s_tilde.gsub(/\uFF5E/, "\u301C")
    assert_equal s,        preprocess_space_zenkaku(s_tilde)
    assert_equal '(あ)〜', preprocess_space_zenkaku("（あ）～")  # @example in comment in convert_ja_chars()
  end

  test "definite_article_to_tail" do
    assert_equal "Beatles, The", definite_article_to_tail("The Beatles")
    assert_equal "Beatles, the", definite_article_to_tail("the Beatles")
    assert_equal "Beatles, The", definite_article_to_tail("Beatles, The")
    assert_equal "france, la", definite_article_to_tail("la france")
    assert_equal "Amour Maternel, L'", definite_article_to_tail("L'Amour Maternel")

    assert_equal "The Beatles", definite_article_to_head("Beatles, The")
    assert_equal "the Beatles", definite_article_to_head("Beatles, the") # lower-case
    assert_equal "the Beatles", definite_article_to_head("the Beatles")
    assert_equal "la france", definite_article_to_head("france, la")
    assert_equal "L'Amour Maternel", definite_article_to_head("L'Amour Maternel")

    assert_equal "Beatles", definite_article_stripped("Beatles, The")
    assert_equal "france",  definite_article_stripped("france, la")
    assert_equal "france",  definite_article_stripped("La france")
    assert_equal "Lafrance",  definite_article_stripped("Lafrance")
    assert_equal "Amour Maternel",  definite_article_stripped("L'Amour Maternel")

    re, outstr, the = definite_article_with_or_not_at_tail_regexp("The Beatles")
    assert_match(re, "Beatles, The")
    assert_match(re, "beatles, the")
    assert_match(re, "beatles")
    assert_no_match(re, " beatles")
    assert_no_match(re, "beatles, Les")
    assert_equal 'Beatles', outstr
    assert_equal 'The', the

    re, outstr, the = definite_article_with_or_not_at_tail_regexp("Beatles, Los")
    assert_match(re, "Beatles, Los")
    assert_match(re, "beatles, los")
    assert_match(re, "beatles")
    assert_no_match(re, " beatles")
    assert_no_match(re, "beatles, The")
    assert_equal 'Beatles', outstr
    assert_equal 'Los', the

    re, outstr, the = definite_article_with_or_not_at_tail_regexp("Beatles")
    assert_match(re, "Beatles, Los")
    assert_match(re, "beatles, the")
    assert_match(re, "beatles")
    assert_no_match(re, " beatles")
    assert_match(re, "beatles, The")
    assert_equal 'Beatles', outstr
    assert_equal '', the

    assert_equal ["Beatles", "The"], partition_root_article("Beatles, The")
    assert_equal ["Beatles", ""],    partition_root_article("Beatles")
    assert_equal ["Beatles", "Los"], partition_root_article("Beatles, Los")
    assert_equal ["Beatles,",""],    partition_root_article("Beatles,") # though wrong for a DB entry.
    assert_equal ["Earth, Wind & Fire",""], partition_root_article("Earth, Wind & Fire")

  end

  test "number_ordered_keys" do
    hs =  {ghi: 'G', jkl: 'J', abc: nil, def: nil, mno: 'G'}
    exp = {abc: 1, def: 1, ghi: 3, mno: 3, jkl: 5}
    assert_equal exp, number_ordered_keys(hs)

    exp = {jkl: 1, mno: 2, ghi: 2, def: 4, abc: 4}
    assert_equal exp, number_ordered_keys(hs, reverse: true)

    exp = {ghi: 1, mno: 1, jkl: 3, abc: 4, def: 4, }
    assert_equal exp, number_ordered_keys(hs, nil_is_minimum: false)

    exp = {def: 1, abc: 1, jkl: 3, mno: 4, ghi: 4, }
    assert_equal exp, number_ordered_keys(hs, nil_is_minimum: false, reverse: true)
  end

  test "get_pair_tags_from_css" do
    sample = 'div.entry-content.R3#XY table tr'
    exps = ["<div id=\"XY\" class=\"entry-content R3\">\n<table>\n<tr>", "</tr>\n</table>\n</div>"]
    assert_equal exps, get_pair_tags_from_css(sample)

    sample = 'div.entry-content table tr'
    exps = ["<div class=\"entry-content\">\n<table>\n<tr>", "</tr>\n</table>\n</div>"]
    assert_equal exps, get_pair_tags_from_css(sample)
  end

  test "remove_az_from_regexp" do
    assert_equal(/xYz?/i,  remove_az_from_regexp(/\AxYz?\Z/i, remove_first: true, remove_last: true))
    assert_equal(/xYz?$/i, remove_az_from_regexp(/^xYz?$/i, remove_first: true, remove_last: false))
    assert_equal(/^xYz?/i,  remove_az_from_regexp(/^xYz?\z/i, remove_first: false, remove_last: true))
  end

  test "definite articles handling" do
    ## partition_root_article
    assert_equal %w(abc La),  partition_root_article("abc,  La")
    assert_equal %w(abc tHe), partition_root_article("abc, tHe")
    assert_equal ["abc,the", ""],  partition_root_article("abc,the"),  "DB-entry style should be assumed"
    assert_equal ["the  abc", ""], partition_root_article("the  abc"), "DB-entry style should be assumed"
    assert_equal ["La La La", ""], partition_root_article("La La La"), "should be empty-String, not nil"

    ## definite_article_stripped
    assert_equal "abc",    definite_article_stripped("abc,  La")
    assert_equal "abc",    definite_article_stripped("abc,the"), "space should not be mandatory after ','"
    assert_equal "abc",    definite_article_stripped("La  abc")
    assert_equal "abc",    definite_article_stripped("L'abc")
    assert_equal "La  La La", definite_article_stripped("La  La La"), "should be a special case"

    ## definite_article_to_head
    assert_equal "The Beatles", definite_article_to_head("Beatles, The") # in @example
    assert_equal "La abc",    definite_article_to_head("abc,  La")
    assert_equal "the abc",   definite_article_to_head("abc,the")
    assert_equal "La  abc",   definite_article_to_head("La  abc")
    assert_equal "L'abc",     definite_article_to_head("L'abc")
    assert_equal "La  La La", definite_article_to_head("La  La La")

    ## definite_article_to_tail
    assert_equal "Beatles, The", definite_article_to_tail("The Beatles") # in @example
    assert_equal "abc,  La",  definite_article_to_tail("abc,  La")
    assert_equal "abc,the",   definite_article_to_tail("abc,the")
    assert_equal "abc, La",   definite_article_to_tail("La  abc")
    assert_equal "abc, L'",   definite_article_to_tail("L'abc")
    assert_equal "the abc, La",  definite_article_to_tail("the abc, La"), "should not be doubly tailed." # in @example 
    assert_equal "La  La La", definite_article_to_tail("La  La La"), "should be a special case"

    ## definite_article_with_or_not_at_tail_regexp
    exp = [/\A(Beatles)(,\s*(tHe))?\z/i, "Beatles", "tHe"]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("tHe Beatles") # in @example
    exp = [/\A(Beatles)(,\s*(#{DEFINITE_ARTICLES_REGEXP_STR}))?\z/i, "Beatles", ""]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("Beatles") # in @example
    exp = [/\A(abc)(,\s*(La))?\z/i, "abc", "La"]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("abc,  La")
    exp = [/\A(abc)(,\s*(the))?\z/i, "abc", "the"]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("abc,the")
    exp = [/\A(abc)(,\s*(La))?\z/i, "abc", "La"]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("La  abc")
    exp = [/\A(abc)(,\s*(L'))?\z/i, "abc", "L'"]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("L'abc")
    exp = [/\A(La\ \ La\ La)(,\s*(#{DEFINITE_ARTICLES_REGEXP_STR}))?\z/i, "La  La La", ""]
     assert_equal exp, definite_article_with_or_not_at_tail_regexp("La  La La"), "should be a special case"
  end

  test "regexp_ruby_to_postgres" do
    assert_equal ["abc+d", "n"], regexp_ruby_to_postgres(/abc+d/)
    assert_equal ['^ab\Z', 'in'], regexp_ruby_to_postgres(/^ab\z/i)
    assert_match(/^ab\\z/i, 'ab\zxyz')  # sanity check
    assert_equal ["^ab\\\\z", 'in'], regexp_ruby_to_postgres(/^ab\\z/i)  # independent backslash
    assert_equal ['\Aab\s*\Z', 'iw'], regexp_ruby_to_postgres(/\Aab\Z/im)
    assert_equal ['ab\yx$', 'in'], regexp_ruby_to_postgres(/ab\bx$/i)
    assert_equal ["ab\\\\bx$", 'in'], regexp_ruby_to_postgres(/ab\\bx$/i)

    # \b in Range remains, \b elsewhere including "(\[\b\])" is replaced to "\y".
    # In the example below, the second "\b" should remain as it is.
    rexb = /\\\[b\b,m\][a\]b\bc]+d\\be:\bf/  # \b in Range and "\\b" remain, \b elsewhere including "(\[\b\])" are replaced
    assert_equal ["\\\\\\[b\\y,m\\][a\\]b\\bc]+d\\\\be:\\yf", 'n'], regexp_ruby_to_postgres(rexb)

    conn = ActiveRecord::Base.connection
    assert _match_rb_psql_regexp?(conn, /abc+d/,   "abcccd")
    assert _match_rb_psql_regexp?(conn, /abc+d/,   "Abcccd", false)
    assert _match_rb_psql_regexp?(conn, /abc+d/im, "Abcccd")
    assert _match_rb_psql_regexp?(conn, /\Ac.d/xi,   "c\nd", false)
    assert _match_rb_psql_regexp?(conn, /\Ac.d/mi,   "c\nd")
    assert _match_rb_psql_regexp?(conn, /\Ac.d/mi, "\nc\nd", false)
    assert _match_rb_psql_regexp?(conn, /^c.d/mi,  "\nc\nd")
    assert _match_rb_psql_regexp?(conn, /\Aab\z|cd\z/im,  "ab"), "Ruby(\\z) == PostgreSQL(\\Z)"
    assert _match_rb_psql_regexp?(conn, /\Aab\\z|cd\z/im, "ab", false)
    assert _match_rb_psql_regexp?(conn, /\Aab\z/im, "ab\n", false)
    assert _match_rb_psql_regexp?(conn, /\Aab\Z/im, "ab"),  "Ruby(\\Z) != PostgreSQL(\\Z)"
    assert _match_rb_psql_regexp?(conn, /ab\Z|cd\Z/im,  "aB\n")
    assert _match_rb_psql_regexp?(conn, /ab\\Z|cd\Z/im, "aB\n", false)
    assert _match_rb_psql_regexp?(conn, /ab\b/i,  "Ab cd")
    assert _match_rb_psql_regexp?(conn, /ab\b/i,  "Abcd", false)
    assert _match_rb_psql_regexp?(conn, rexb, "\\[b,m]cd\\be:f")
  end

  test "convert_str_to_number_nil" do
    assert_nil convert_str_to_number_nil(nil)
    assert_nil convert_str_to_number_nil("  ")
    assert_nil convert_str_to_number_nil([])
    assert_equal [?a], convert_str_to_number_nil([?a])
    assert_equal "abc", convert_str_to_number_nil("abc")
    assert_equal 0, convert_str_to_number_nil(" 0 ")
    assert_equal 0.4, convert_str_to_number_nil(" 0.4 ")
    assert_equal(-3_0.243_24_2, convert_str_to_number_nil(" -3_0.243_24_2 "))
    assert_equal(-5_6.23_43e-52_3 , convert_str_to_number_nil(" -5_6.23_43e-52_3 "))
  end

  test "singleton_method_val" do
    obj = Object.new
    assert_equal 5, set_singleton_method_val(:metho, initial_value=5, target: obj)
    assert   obj.respond_to?(:metho)
    assert_equal 5, obj.metho
    assert_equal 7, obj.metho=7
    assert_equal 7, obj.metho
    assert_equal 8, set_singleton_method_val(:metho, initial_value=8, target: obj)
    assert_equal 8, obj.metho, 'should change, but...'
    assert_equal 8, set_singleton_method_val(:metho, initial_value=9, target: obj, clobber: false)
    assert_equal 8, obj.metho, 'should change nothing, but...'

    art = Artist.new
    assert_equal 5, art.set_singleton_method_val(:metho, initial_value=5)
    assert   art.respond_to?(:metho)
    assert_equal 5, art.metho
  end

  private
    # Returns true if Ruby and PosgreSQL results match.
    def _match_rb_psql_regexp?(conn, re_ruby, str, regexp_should_succed=true)
      result_psql = _get_rows00(_res_postgres(conn, re_ruby, str))
      result_rb   = re_ruby.match(str)
      (!!result_psql == !!result_rb) && (!!result_rb == regexp_should_succed)
    end

    # @return [ActiveRecord::Result] PostgreSQL Regexp result. +.rows[0][0]+ always exists but may be nil.
    def _res_postgres(conn, re_ruby, str)
      re_psql, re_opts = regexp_ruby_to_postgres(re_ruby)
      # print "DEBUG(#{__method__}): ary=";p [re_psql, re_opts]
      conn.exec_query("SELECT REGEXP_MATCHES('#{str}', '#{re_psql}', '#{re_opts}');") 
    end

    # `ActiveRecord::Result.rows` is sometimes `[]` and sometimes `[[nil]]` when empty.
    # This returns nil in either case.
    #
    # @param res [ActiveRecord::Result]
    # @return [String, NilClass]
    def _get_rows00(res)
      return nil if res.rows.empty?
      res.rows[0][0]
    end
end

