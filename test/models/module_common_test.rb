# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
  include ModuleCommon

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

  test "regexp_ruby_to_postgres" do
    assert_equal ["abc+d", "n"], regexp_ruby_to_postgres(/abc+d/)
    conn = ActiveRecord::Base.connection
    assert     _get_rows00(_res_postgres(conn, /abc+d/,   "abcccd"))
    assert_nil _get_rows00(_res_postgres(conn, /abc+d/,   "Abcccd"))
    assert     _get_rows00(_res_postgres(conn, /abc+d/im, "Abcccd"))
    assert_nil _get_rows00(_res_postgres(conn, /\Ac.d/xi,   "c\nd"))
    assert     _get_rows00(_res_postgres(conn, /\Ac.d/mi,   "c\nd"))
    assert_nil _get_rows00(_res_postgres(conn, /\Ac.d/mi, "\nc\nd"))
    assert     _get_rows00(_res_postgres(conn, /^c.d/mi,  "\nc\nd"))
  end

  private
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

