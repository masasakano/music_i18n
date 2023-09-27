# coding: utf-8
require 'test_helper'

class DownloadHarami1129Test < ActiveSupport::TestCase
  Klass = Harami1129s::DownloadHarami1129 
  include ModuleCommon

  setup do
    # Reset ENV['URI_HARAMI1129'] for local-testing. Default: DEF_RELPATH_HARAMI1129_LOCALTEST in test_helper.rb
    set_uri_harami1129_localtest  # defined in test_helper.rb
  end

  test "self.generate_sample_html_table" do
    sample =
      case Klass::HARAMI1129_HTML_FMT.strip
      when "2022"
        'あいみょん,マリーゴールド,2019/7/20,Link→【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s'
      else
        'あいみょん,マリーゴールド,2019/7/20,追記だよ,【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s'
      end
    case Klass::HARAMI1129_HTML_FMT
    when "2022"
      exp = <<EOF
<div class="entry-content">
<table>
<tr><th>アーティスト</th><th>曲名</th><th>リリース日</th><th>リンク</th></tr>
<tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td><font color="red">Link→</font><a rel="noopener" target="_blank" href="https://youtu.be/N9YpRzfjCW4?t=4816s">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a><br/>https://youtu.be/N9YpRzfjCW4?t=4816s</td></tr>
</table>
</div>
EOF
    else
      exp = <<EOF
<table>
<tr><th>アーティスト</th><th>曲名</th><th>リリース日</th><th>メモ</th><th>リンク</th></tr>
<tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td>追記だよ</td><td><a href=\"https://youtu.be/N9YpRzfjCW4?t=4816s\" target=\"_blank\">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a></td></tr>
</table>
EOF
    end

    exp.chop!
    assert_equal exp, Klass.generate_sample_html_table(sample, html_fmt: Klass::HARAMI1129_HTML_FMT)
  end

end

