# coding: utf-8

# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
  include ModuleCommon
  MC = ModuleCommon

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

  test "diff_emoji_only?" do
    s3 = "ab??cd"
    s4 = "ab\u{1F979}cd"
    assert diff_emoji_only?(s3, s4)
    refute diff_emoji_only?(s3, "abXcd")
    # refute diff_emoji_only?("You?", "You")  # TODO!!!!!!!!!!!!!!
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

  test "capture_stderr" do
    output = Artist.capture_stderr{
      warn "abc"
      123
    }
    assert_equal "abc", output.chop

    ret = self.class.silence_streams($stderr){
      # puts "This should be printed!"
      warn "This should not be printed..."
      123
    }
    assert_equal 123, ret
  end

  test "xpath_contain_text" do
    exp = "contains(., 'CLick')"
    assert_equal exp, MC.xpath_contain_text_single('CLick', case_insensitive: false)

    exp = "contains(translate(.,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'), 'click')"
    assert_equal exp, MC.xpath_contain_text_single('CLick', case_insensitive: true)

    act = MC.xpath_contain_text_single("Dr X's sign", case_insensitive: false)
    exp = %q@contains(., concat('Dr X',"'",'s sign'))@  # '
    assert_equal exp, act

    act = MC.xpath_contain_text("Dr X's sign", "CLick", case_insensitive: false)
    exp = %q@contains(., concat('Dr X',"'",'s sign')) and contains(., 'CLick')@  # '
    assert_equal exp, act
  end

  test "xpath_contain_css" do
    exp = "contains(concat(' ', normalize-space(@class), ' '), ' foo ') and contains(concat(' ', normalize-space(@class), ' '), ' baa ')"
    assert_equal exp, ModuleCommon.xpath_contain_css("foo", "baa")
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

    assert_raises(NameError){
      output = Artist.capture_stderr{
        set_singleton_method_val(:empty?, initial_value=true,  target: obj)
      }
    }

    assert set_singleton_method_val(:empty?, initial_value=true,  target: obj, reader: true)
    assert obj.respond_to?(:empty?)
    assert obj.empty?
    refute set_singleton_method_val(:empty?, initial_value=false, target: obj, reader: true, clobber: true)
    assert obj.respond_to?(:empty?)
    refute obj.empty?

    class Object2
      include ModuleCommon
      def naiyo?
        8
      end
    end
    obj2 = Object2.new
    refute obj.respond_to?(:naiyo?)
    # assert_equal 8, obj2.set_singleton_method_val(:naiyo?, "damedayo", target: obj, reader: true, derive: true)  # This should print out warning message to STDOUT (and Rails log).  Uncomment it to test this.
    assert_equal 8, obj2.set_singleton_method_val(:naiyo?, target: obj, reader: true, derive: true)
    assert obj.respond_to?(:naiyo?)
    assert_equal 8, obj2.naiyo?

    assert String.new.set_singleton_method_val(:empty?, target: obj2, reader: true, derive: true)
    assert obj2.respond_to?(:empty?)
    assert obj2.empty?
  end

  test "time_err2uptomin" do
    time = Time.new(1984,2,3,4,5,1)
    assert_equal "1984年2月3日 04:——", time_err2uptomin(time, 70.minute, langcode: "ja")
  end

  test "time_in_units" do
    ar3 = [:day, :hour, :min]
    assert_raises(ArgumentError){ time_in_units(1, units: [:naiyo]) }
    assert_equal "0.5 [days] | 12.0 [hrs] | 720.0 [mins]", time_in_units(720*60, units: ar3)
    assert_equal "0.5 [日] | 12.0 [時間] | 720.0 [分]",    time_in_units(720*60, units: ar3, langcode: "ja")
    assert_equal "0.5 [days] | 12.0 [hrs] | 720.0 [mins]", time_in_units(720.minutes, units: ar3)
    assert_equal "0.5 [days] | 12.0 [hrs] | 720.0 [mins]", time_in_units(720.minutes, units: ar3)
    assert_equal "0.5 [days]",                             time_in_units(720.minutes, units: [:day])
    assert_equal "0.5 [days] | 12.0 [hrs]",                time_in_units(720.minutes, units: [:day, :hour])
    
    assert_equal "0.5 [days] | 12 [hrs] | 720 [mins]", time_in_units(720.minutes, units: :auto3)
    assert_equal "0.5 [days] | 12 [hrs] | 720 [mins]", time_in_units(720.minutes)
    assert_equal "42.5 [days]",        time_in_units(42.5.days)
    assert_equal "4 [days] | 96 [hrs]", time_in_units(4.days)
    assert_equal "4.25 [days] | 102 [hrs]", time_in_units(4.25.days)
    assert_equal "4.26 [days] | 102 [hrs]", time_in_units(4.259.days)
    assert_equal "0 [mins]", time_in_units(0)
    assert_equal "0.70 [days] | 16.7 [hrs]", time_in_units(1001.minutes)
    assert_equal "0.10 [days] | 2.5 [hrs] | 150 [mins]", time_in_units(150.minutes)
    assert_equal "0.11 [days] | 2.58 [hrs] | 155 [mins]", time_in_units(155.minutes)  # day for %.2f, hr for %.3g
    assert_equal "2.3 [hrs] | 138 [mins]", time_in_units(0.096.days)
    assert_equal "5.75 [mins]", time_in_units(0.096.hours)
    assert_equal "infinity [days]", time_in_units(Float::INFINITY)
    assert_equal "infinity [days]", time_in_units(1001.days)
    assert_equal "infinity [days]", time_in_units(nil)
    assert_equal 'infinity<span class="editor_only">([Editor] nil) </span>[days]', time_in_units(nil, for_editor: true)
  end

  test "order_prioritized_with" do
    sex = Sex.third
    assert_equal sex, order_prioritized_with(Sex,     sex).first
    assert_equal sex, order_prioritized_with(Sex.all, sex).first
    ar_sexes = Sex.all.to_a
    assert_equal sex, order_prioritized_with(ar_sexes, sex).first
  end

  test "significantly_changed?" do
    pro = PlayRole.create_basic!(title: "test-mu", langcode: "en", is_orig: true, mname: "test12", weight: 7592)
    assert_nil pro.note, 'sanity check'

    refute pro.changed?, 'Rails spec'
    refute significantly_changed?(pro)

    # DB: note => nil
    pro.note = nil
    refute pro.changed?, 'Rails spec'
    refute significantly_changed?(pro)
    pro.note = "abc"
    assert pro.changed?, 'Rails spec'
    assert significantly_changed?(pro)
    pro.note = ""
    assert pro.changed?, 'Rails spec'
    refute significantly_changed?(pro)

    # DB: note => ""
    pro.save!

    pro.note = nil
    assert pro.changed?, 'Rails spec'
    refute significantly_changed?(pro)
    pro.note = "abc"
    assert pro.changed?, 'Rails spec'
    assert significantly_changed?(pro)
    pro.note = ""
    refute pro.changed?, 'Rails spec'
    refute significantly_changed?(pro)

    # DB: note => "abc"; changed? and significantly_changed? are equivalent.
    pro.note = "abc"
    pro.save!

    pro.note = nil
    assert pro.changed?, 'Rails spec'
    assert significantly_changed?(pro)
    pro.note = "abc"
    refute pro.changed?, 'Rails spec'
    refute significantly_changed?(pro)
    pro.note = ""
    assert pro.changed?, 'Rails spec'
    assert significantly_changed?(pro)
  end

  test "fetch_url_h1" do
    assert_equal "Example Domain", fetch_url_h1("http://example.com"), "This may fail if the network connection is unsable..."
  end

  test "transfer_errors" do
    sex = Sex.new(iso5218: nil)
    sex.unsaved_translations << Translation.new(title: "random", langcode: "en")
    refute sex.valid?
    assert sex.new_record?, 'sanity check'
    assert sex.errors.any?, 'sanity check'

    assert_equal 1, sex.errors.size
    assert_equal [:iso5218], sex.errors.attribute_names
    assert_equal 1, sex.errors.messages_for(sex.errors.attribute_names.first).size
    errmsg1 = sex.errors.messages_for(:iso5218)

    errmsgs = {}
    [:iso5218, :note, Sex::FORM_TRANSLATION_NEW_TAGS[:alt_title], :arbitrary].each_with_index do |tag, i_err|
      errmsgs[tag] = "#{tag.to_s}-error"
      sex.errors.add tag, errmsgs[tag]
      assert_equal i_err+2, sex.errors.size
      assert_includes sex.errors.attribute_names, tag
      assert_equal ((:iso5218 == tag) ? 2 : 1), sex.errors.messages_for(tag).size
    end

    assert_equal 5, sex.errors.full_messages.size, 'sanity check'
    assert_equal 4, sex.errors.attribute_names.size

    record = Country.last
    errmsgs[:base]  = errmsgs[:arbitrary]  # preparation (the error is transferred to Attribute :base)
    errmsgs[:myown] = errmsgs[:iso5218]    # preparation

    refute record.errors.any?, 'sanity check'
    record.transfer_errors(sex, mappings: {iso5218: :myown})

    assert record.errors.any?
    assert_equal 5, record.errors.size
    assert_equal 4, record.errors.attribute_names.size
    assert_includes record.errors.messages_for(:myown), errmsgs[:iso5218]

    [:note, Sex::FORM_TRANSLATION_NEW_TAGS[:alt_title]].each do |tag|
      assert_equal(   sex.errors.messages_for(tag),
                   record.errors.messages_for(tag) )
    end

    [[:iso5218, :myown], [:arbitrary, :base]].each do |from, to|
      assert_equal(   sex.errors.messages_for(from),
                   record.errors.messages_for(to) )
    end
  end

  test "uniq_dbl_ary_by" do
    ar = [[3,?a,?c], [4,?a,?d], [3,?x,?y]]
    exp = [[3,?a,?c], [4,?a,?d]]
    assert_equal exp, uniq_dbl_ary_by(ar, 0)
    exp = [[3,?a,?c], [3,?x,?y]] 
    assert_equal exp, uniq_dbl_ary_by(ar, 1)
    exp = [[3,?a,?c], [4,?a,?d], [3,?x,?y]] 
    assert_equal exp, uniq_dbl_ary_by(ar, 2)
    exp = [[3,?a,?c], [4,?a,?d]]
    assert_equal exp, uniq_dbl_ary_by(ar, 2, maxsize: 2)
  end

  test "camel_cased_truncated" do
    assert_equal "KingArthur", camel_cased_truncated("KING Arthur")
    assert_equal "KingArthur", camel_cased_truncated("king arthur")
    assert_equal "KingArthur", camel_cased_truncated("king arthur, the")
    assert_equal "HeyHeyJump", camel_cased_truncated("Hey! hey! jump.")
    assert_equal "ArtMusicTitle", camel_cased_truncated("art-music TITLE")
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

