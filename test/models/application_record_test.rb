# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
 
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

