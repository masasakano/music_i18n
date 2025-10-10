# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
 
  test "ApplicationRecord.utf8collation_for" do
    assert_equal "und-x-icu",   ApplicationRecord.utf8collation_for
    assert_equal "und-x-icu",   ApplicationRecord.utf8collation_for(provider: "icu")
    assert_equal "en-GB-x-icu", ApplicationRecord.utf8collation_for("en_GB")
    assert_equal "ja-x-icu", ApplicationRecord.utf8collation_for("ja")
    assert_equal "ja-x-icu", ApplicationRecord.utf8collation_for("ja_XX")
    assert_equal "und-x-icu",   ApplicationRecord.utf8collation_for("C")

    assert_raises(ArgumentError){ApplicationRecord.utf8collation_for("und", provider: "invalid")}
    assert_raises(ArgumentError){ApplicationRecord.utf8collation_for("und", provider: "libc")}
    assert_raises(ArgumentError){ApplicationRecord.utf8collation_for("C",   provider: "libc", dialect: "XX")}
    assert_raises(ArgumentError){ApplicationRecord.utf8collation_for(       provider: "libc", dialect: "XX")}

    case RUBY_PLATFORM
    when /darwin|bsd/i
      assert_equal "en_GB.UTF-8", ApplicationRecord.utf8collation_for("en_GB", provider: "libc")
      assert_equal "ja_JP.UTF-8", ApplicationRecord.utf8collation_for("ja_JP", provider: "libc")
      assert_equal "ja_JP.UTF-8", ApplicationRecord.utf8collation_for("ja_JP", provider: "libc")  # repeat (to test the implemented cache)
      assert_equal "ja_JP.UTF-8", ApplicationRecord.utf8collation_for("ja_JP", provider: "libc")  # repeat (to test the implemented cache)
      assert_equal "C.UTF-8",     ApplicationRecord.utf8collation_for("af_XX", provider: "libc")  # "af_NA" may exist, but not "XX"
      assert_equal "C.UTF-8",     ApplicationRecord.utf8collation_for("af_XX", provider: "libc")  # repeat
      assert_equal "C.UTF-8",     ApplicationRecord.utf8collation_for(provider: "libc")
    when "linux"
      assert_equal "en_GB.utf8",  ApplicationRecord.utf8collation_for("en_GB", provider: "libc")
    else
      # skip
    end

    act = with_captured_stderr{
      # WARNING: Unexpected language (naiyo) specified for method(utf8collation) in /.../app/models/application_record.rb  Returning the default value. See log for the backtrace.
      assert_equal "und-x-icu", ApplicationRecord.utf8collation_for("naiyo")
    }
    assert_includes act, "Unexpected "
  end
 
  test "logger_title" do
    mus = musics(:music_light)
    val = mus.logger_title
    exp = "(ID=#{mus.id}: \"Light, The\")"
    assert_equal exp, val
     
    se=Sex[9]
    val = se.logger_title(fmt: se.class::LOGGER_TITLE_FMT.sub(/^\(([^)]+)\)$/, '[\1]'))
    exp = '[ID=9: "not applicable"]'
    assert_equal exp, val

    se=Sex[9]
    val = se.logger_title(extra: [" / ISO=#{se.iso5218}"])
    exp = '(ID=9: "not applicable" / ISO=9)'
    assert_equal exp, val

    se=Sex[1]
    val = se.logger_title(method: :alt_title)
    exp = '(ID=1: "M")'
    assert_equal exp, val
  
    se=Sex[9]
    val = se.logger_title(){ |method, extra, fmt|
       sprintf fmt, se.id.inspect,
                    se.title_or_alt(langcode: "ja", lang_fallback_option: :either, str_fallback: "", article_to_head: true).inspect,
                    " [#{se.iso5218} : #{se.updated_at}]"
     }
    exp = "(ID=9: \"適用不能\" [9 : #{se.updated_at}])"
    assert_equal exp, val

    val = Artist.logger_titles([Sex[1], Sex[2]])
    exp = '[(ID=1: "male"), (ID=2: "female")]'
    assert_equal exp, val
  end

  private
end

