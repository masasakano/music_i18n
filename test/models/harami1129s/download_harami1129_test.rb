# coding: utf-8
require 'test_helper'

class DownloadHarami1129Test < ActiveSupport::TestCase
  Klass = Harami1129s::DownloadHarami1129 
  include ModuleCommon

  test "self.generate_sample_html_table" do
    ## Old style up to mid(?)-2022
    #sample = 'あいみょん,マリーゴールド,2019/7/20,【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s'
    sample = 'あいみょん,マリーゴールド,2019/7/20,【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)'
    exp = <<EOF
<div class="entry-content">
<table>
<tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td></td><td><a href="https://youtu.be/N9YpRzfjCW4?t=4816s" target="_blank">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a></td></tr>
</table>
</div>
EOF
    exp.chop!
    assert_equal exp, Klass.generate_sample_html_table(sample, url: "https://youtu.be/N9YpRzfjCW4?t=4816s")
  end

end

