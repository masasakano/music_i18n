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

  private
end

