# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
  include ApplicationHelper

  AH = ApplicationHelper

  test "normalized_uri_youtube" do
    k = "https://Youtu.Be:80/BBBCCCCQxU4?si=AAA5OOL6ivmJX999&t=53s&link=youtu.be&list=OLAK5uy_k-vV"

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: true,  with_time: false, with_host: false)
    exp = "BBBCCCCQxU4"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: true,  with_time: false, with_host: true)
    exp = "youtu.be/BBBCCCCQxU4"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: true)
    exp = "youtu.be/BBBCCCCQxU4"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: true,  with_host: true)
    exp = "youtu.be/BBBCCCCQxU4?t=53"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: false, with_query: true,  with_time: false, with_host: true)
    exp = "www.youtube.com/watch?v=BBBCCCCQxU4"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: false, with_query: false, with_time: true,  with_host: true)
    exp = "www.youtube.com/watch?t=53&v=BBBCCCCQxU4"
   #exp = "www.youtube.com/watch?v=BBBCCCCQxU4&t=53"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: true,  with_query: false, with_time: true,  with_host: true)
    exp = "https://www.youtube.com/watch?t=53&v=BBBCCCCQxU4"
   #exp = "https://www.youtube.com/watch?v=BBBCCCCQxU4&t=53"
    assert_equal exp, val

    ### standard full-forms
    k = "www.youtube.com/watch?v=BBBCCCCQxU4&t=53"

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: true,  with_host: true)
    exp = "youtu.be/BBBCCCCQxU4?t=53"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: false, with_query: true,  with_time: false, with_host: true)
    exp = "www.youtube.com/watch?v=BBBCCCCQxU4"
    assert_equal exp, val

    ### shorts
    k = "youtube.com:8080/shorts/r0-9FXPIS8E?si=Xzx1rFkXXXKXCRm8"

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: true,  with_time: false, with_host: true)
    exp = "youtu.be:8080/r0-9FXPIS8E"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: true,  with_query: true,  with_time: false, with_host: true)
    exp = "https://www.youtube.com:8080/watch?v=r0-9FXPIS8E"
    assert_equal exp, val

    ### live stream and embed
    %w(live embed).each do |dir1st|
      k = "https://www.youtube.com/#{dir1st}/vXABC6EvPXc?si=OOMorKVoVqoh-S5h&t=53"
  
      val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: true,  with_time: true,  with_host: true)
      exp = "youtu.be/vXABC6EvPXc?t=53"
      assert_equal exp, val
  
      val = AH.normalized_uri_youtube(k, long: true,  with_scheme: true,  with_query: true,  with_time: true,  with_host: true)
      exp = "https://www.youtube.com/watch?t=53&v=vXABC6EvPXc"
     #exp = "https://www.youtube.com/watch?v=vXABC6EvPXc&t=53"
      assert_equal exp, val
    end

    ### General URI
    k = "www.EXAMPLE.com/LIVE/watch?v=BBBCCCCQxU4&t=53&si=XXX"

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: true,  with_time: false, with_host: false)
    exp = "LIVE/watch?v=BBBCCCCQxU4&t=53&si=XXX"
    assert_equal exp, val, "long and with_time are ignored."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: true)
    exp = "www.example.com/LIVE/watch"
    assert_equal exp, val, "long and with_time are ignored."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: true,  with_query: false, with_time: false, with_host: false)
    exp = "https://www.example.com/LIVE/watch"
    assert_equal exp, val, "long and with_time are ignored."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: false)
    exp = "LIVE/watch"
    assert_equal exp, val, "long and with_time are ignored."
  end

  test "sanitized_html" do
    strin = '<a href="abc"><em>here</em></a> <script> some </script>&ldquo;&ouml;&euro;&#x3042;&rdquo; 1 > 2&'
    exp = "<a href=\"abc\" target=\"_blank\"><em>here</em></a>  some “ö€あ” 1 &gt; 2&amp;"
    assert_equal exp, sanitized_html(strin)
    
    exp = '<a href="abc">here</a>  some “ö€あ” 1 &gt; 2&amp;'
    assert_equal exp, sanitized_html(strin, targetblank: false, permitted: %w(a))

    exp = '<a href="abc" rel="nofollow"><em>here</em></a>  some “ö€あ” 1 &gt; 2&amp;'
    assert_equal exp, sanitized_html_fragment(strin, targetblank: false).scrub!(:nofollow).to_s
  end

  test "sec2hms_or_ms" do
    assert_nil   sec2hms_or_ms(nil, return_nil: true)
    assert_equal "00:00", sec2hms_or_ms(nil)
    assert_equal     "0", sec2hms_or_ms(nil, return_if_zero: "0")
    assert_equal "00:00", sec2hms_or_ms(0)
    assert_equal     "0", sec2hms_or_ms(0, return_if_zero: "0")
    assert_equal "00:01", sec2hms_or_ms(1)
    assert_equal "11:09", sec2hms_or_ms(669)
    assert_equal "01:01:01", sec2hms_or_ms(3661)
    assert_equal "-00:06",    sec2hms_or_ms(-6)
    assert_equal "-01:01:01", sec2hms_or_ms(-3661)
    assert_equal "59:54", sec2hms_or_ms(-6, negative_from_60min: true)
  end

  test "hms2sec" do
    assert_nil   hms2sec(nil)
    assert_nil   hms2sec("", blank_is_nil: true)
    assert_equal    0, hms2sec("")
    assert_equal    9, hms2sec("09")
    assert_equal    9, hms2sec("00:09")
    assert_equal    9, hms2sec("00:09")
    assert_equal 1234, hms2sec("1234")
    assert_equal   83, hms2sec("01:23")
    assert_equal 3683, hms2sec("1:01:23")
    assert_equal 45296, hms2sec('12:34:56')
    assert_equal  2096, hms2sec('34:56')
    
    assert_equal    0, hms2sec("0")
    assert_equal(  -5, hms2sec("-5"))
    assert_equal( -87, hms2sec(" -87"))
    assert_equal(-3683, hms2sec("  -1:01:23"))
  end
 
  private
end

