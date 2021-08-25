# coding: utf-8
require 'test_helper'

class DownloadHarami1129Test < ActiveSupport::TestCase
  Klass = Harami1129s::DownloadHarami1129 
  include ModuleCommon

  test "self.generate_sample_html_table" do
    sample = 'あいみょん,マリーゴールド,2019/7/20,Link→【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s'
    exp = <<EOF
<div class="entry-content">
<table>
<tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td><font color="red">Link→</font><a rel="noopener" target="_blank" href="https://youtu.be/N9YpRzfjCW4?t=4816s">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a><br/>https://youtu.be/N9YpRzfjCW4?t=4816s</td></tr>
</table>
</div>
EOF
    exp.chop!
    assert_equal exp, Klass.generate_sample_html_table(sample)
  end

end

