# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase
  include ApplicationHelper

  AH = ApplicationHelper

  test "normalized_uri_youtube" do
    query_lc = "lc=UgxffvDXzEaXVHqYcMF4AaABAg"
    k = "https://Youtu.Be:80/BBBCCCCQxU4?si=AAA5OOL6ivmJX999&t=53s&link=youtu.be&list=OLAK5uy_k-vV&"+query_lc

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: false)
    exp = identifier = "BBBCCCCQxU4"
    assert_equal exp, val
    assert_equal exp, AH.get_id_youtube_video(k)
    assert_equal exp, AH.get_id_youtube_video(exp)
    assert_equal exp, AH.get_id_youtube_video("Youtu.Be:80/"+exp)

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: true)
    exp = "youtu.be/BBBCCCCQxU4"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: true,  with_time: false, with_host: true)
    exp = "youtu.be/BBBCCCCQxU4?lc=UgxffvDXzEaXVHqYcMF4AaABAg"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: true,  with_host: true)
    exp = "youtu.be/BBBCCCCQxU4?t=53"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: false, with_query: false, with_time: false, with_host: true)
    exp = "www.youtube.com/watch?v=BBBCCCCQxU4"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: false, with_query: true,  with_time: false, with_host: true)
    exp2= [a=["v="+identifier, query_lc], a.reverse].map{|ea| "www.youtube.com/watch?"+ea[0]+"&"+ea[1]}  # i.e., "www.youtube.com/watch?v=BBBCCCCQxU4&lc=UgxffvDXzEaXVHqYcMF4AaABAg" or its query parameters order reversed
    assert_includes exp2, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: false, with_query: false, with_time: true,  with_host: true)
    exp = "www.youtube.com/watch?t=53&v=BBBCCCCQxU4"
   #exp = "www.youtube.com/watch?v=BBBCCCCQxU4&t=53"
    assert_equal exp, val

    val = AH.normalized_uri_youtube(k, long: true,  with_scheme: true,  with_query: false, with_time: true,  with_host: true)
    exp = "https://www.youtube.com/watch?t=53&v=BBBCCCCQxU4"
   #exp = "https://www.youtube.com/watch?v=BBBCCCCQxU4&t=53"
    assert_equal exp, val

    k2r =         "youtu.be/abcdefghi01"
    k2  = "http://"+k2r
    val = AH.normalized_uri_youtube(k2, long: false, with_scheme: false, with_host: true,  with_time: true)
    exp = k2r
    assert_equal exp, val, "unsafe 'http://' should be handled correctly, but..."

    val = AH.normalized_uri_youtube(k2, long: false, with_scheme: true, with_host: true,  with_time: true)
    exp = "https://"+k2r
    assert_equal exp, val, "unsafe 'http://' should be replaced with 'https', but..."

    k3  = "gopher://"+k2r
    val = AH.normalized_uri_youtube(k3, long: false, with_scheme: false, with_host: true,  with_time: true)
    exp = k3
    assert_equal exp, val, "for gopher etc, with_scheme should be ignored if with_host==true, but..."

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

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: :HaramiVid, with_query: false, with_time: false, with_host: true)
    assert_equal exp, val, "long and with_time are ignored."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: true,  with_query: false, with_time: false, with_host: false)
    exp = "https://www.example.com/LIVE/watch"
    assert_equal exp, val, "long and with_time are ignored."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: false)
    exp = "LIVE/watch"
    assert_equal exp, val, "long and with_time are ignored."

    k = "sftp://example.com/abc/def"
    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: true)
    assert_equal k, val, "Even with with_scheme==false, as long as with_host is true, the non-standard scheme is included."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: false)
    exp = "abc/def"
    assert_equal exp, val, "If both with_scheme and with_host are false, even the non-standard scheme is NOT included."

    val = AH.normalized_uri_youtube(k, long: false, with_scheme: false, with_query: false, with_time: false, with_host: false)
    exp = "abc/def"
    assert_equal exp, val, "If both with_scheme and with_host are false, even the non-standard scheme is NOT included."
  end

  test "guess_site_platform" do
    assert_equal :youtube, AH.guess_site_platform("www.youtube.com/?watch=abc")
    assert_equal :youtube, AH.guess_site_platform("youtu.be/abc")
    assert_equal :tiktok,  AH.guess_site_platform("tiktok.com/?t=abcd")
    assert_equal "example.com",  AH.guess_site_platform("https://www.example.com/abcd")
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
 
  test "link_to_youtube" do
    rk="WeMoOTlQ-Ls"
    page = Nokogiri::HTML( link_to_youtube(rk, root_kwd=nil, timing=5, long: false, target: true, title: (tit="my_title1")) )
    exp = "https://youtu.be/WeMoOTlQ-Ls?t=5s"
    assert_equal exp, page.css("a")[0]["href"], "a is #{page.css('a')[0].inspect}"
    assert_equal tit, page.css("a")[0]["title"]
    assert_equal "_blank", page.css("a")[0]["target"]

    rk="www.tiktok.com/@someone/video/7258229581717556498"
    page = Nokogiri::HTML( link_to_youtube(rk, root_kwd=nil, timing=5, long: false, target: true, title: (tit="my_title1")) )
    exp = "https://"+rk
    assert_equal exp, page.css("a")[0]["href"]
    assert_equal tit, page.css("a")[0]["title"]
    assert_equal "_blank", page.css("a")[0]["target"]
  end
 
  test "uri_youtube" do
    rk="WeMoOTlQ-Ls"
    assert_equal "youtu.be/#{rk}?t=5s",         AH.uri_youtube(rk, timing=5, long: false, with_http: false)
    assert_equal "https://youtu.be/#{rk}?t=5s", AH.uri_youtube(rk, timing=5, long: false, with_http: true)
    a, b = ["v=#{rk}", "t=5s"]
    assert_includes [a+"&"+b, b+"&"+a].map{|i| "www.youtube.com/watch?" + i}, AH.uri_youtube(rk, timing=5, long: true,  with_http: false)
    rk="www.tiktok.com/@someone/video/7258229581717556498"
    assert_equal "https://"+rk, AH.uri_youtube((rk2=rk+"?is_from_webapp=1&sender_device=pc&web_id=7380717489888399999"), timing=5, long: true,  with_http: true)
    assert_equal            rk, AH.uri_youtube(rk2, timing=5, long: true,  with_http: false)
    assert_equal            rk, AH.uri_youtube(rk2, timing=5, long: true,  with_http: :HaramiVid), "NOTE: Specification may have changed?! (See Haramivid.uri_in_db_with_scheme?)"
  end
 
  test "self.parsed_uri_with_or_not" do
    uri = AH.parsed_uri_with_or_not("http://y.com/abc/def", def_scheme: "gopher")
    assert_equal "http", uri.scheme
    assert_equal "y.com", uri.host

    str = "y.com/abc/def"
    uri = AH.parsed_uri_with_or_not(str, def_scheme: "gopher")
    assert_nil   uri.scheme
    assert_nil   uri.host
    assert_equal str, uri.path

    uri = AH.parsed_uri_with_or_not("www.y.com/abc/def", def_scheme: "gopher")
    assert_equal "gopher", uri.scheme
    assert_equal "www.y.com", uri.host
    assert_equal "/abc/def", uri.path

    uri = AH.parsed_uri_with_or_not("youtu.be/abc/def")
    assert_equal "https",   uri.scheme
    assert_equal "youtu.be", uri.host
    assert_equal "/abc/def", uri.path
  end

  test "uri_path_query" do
    uri = URI.parse("https://x.com/abc?d=e")
    assert_equal "/abc?d=e", AH.uri_path_query(uri, without_slash: false)
    assert_equal  "abc?d=e", AH.uri_path_query(uri, without_slash: true)
    uri = URI.parse("/abc?d=e")
    assert_equal "/abc?d=e", AH.uri_path_query(uri, without_slash: true)
  end

  test "_prepend_youtube" do
    exp = "http://x.com/abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)
    exp = "https://x.com:8080/abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)
    exp = "sftp://x.com/abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)
    exp = "x.com/abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)
    exp = "youtu.be/abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)
    exp = "www.youtube.com/watch?v=abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)
    exp = "something.youtube.co.jp/watch?v=abc"
    assert_equal exp, AH.send(:_prepend_youtube, exp)

    ["abc", "abc?t=5", "abc/", "abc/def", "abc/def?t=xyz"].each do |str|
      assert_equal "youtu.be/"+str, AH.send(:_prepend_youtube, str)
    end
  end
 
  test "bracket_or_empty" do
    empty_str_editor = '<span class="editor_only">[]</span>'
    assert_equal "[abc]", bracket_or_empty("[%s]", "abc", false)
    assert_equal "[abc]", bracket_or_empty("[%s]", "abc", true)
    assert_equal "",               bracket_or_empty("[%s]", nil, false)
    assert_equal empty_str_editor, bracket_or_empty("[%s]", nil, true)
    assert_equal "[abc]", bracket_or_empty("[%s%s]", ["abc", ""], false)
    assert_equal "[abc]", bracket_or_empty("[%s%s]", ["abc", ""], true)
    assert_equal "",      bracket_or_empty("[%s]",    "",      false)
    assert_equal "",      bracket_or_empty("[%s%s]", ["", ""], false)
    assert_equal "",      bracket_or_empty("[%s%s]", [nil, ""], false)
    assert_includes bracket_or_empty("[%s]",    "",      true), '<span class="editor_only">'
    assert_includes bracket_or_empty("[%s%s]", ["", ""], true), '<span class="editor_only">'
    assert_equal empty_str_editor, bracket_or_empty("[%s%s]", [nil, ""], true)

    assert_equal "[&lt;abc]", ERB::Util.html_escape("[<abc]"), "sanity check"
    assert          bracket_or_empty("[%s]", "<abc", false).html_safe?
    assert          bracket_or_empty("[%s]", "<abc", true).html_safe?
    assert_includes bracket_or_empty("[%s]", "<abc", false), "&lt;"
    assert_includes bracket_or_empty("[%s]", "<abc", true),  "&lt;"
    assert          bracket_or_empty("[%s]", "<abc".html_safe, false).html_safe?
    assert          bracket_or_empty("[%s]", "<abc".html_safe, true).html_safe?
    assert_includes bracket_or_empty("[%s]", "<abc".html_safe, true), "&lt;"
    assert          bracket_or_empty("[%s]".html_safe, "<abc".html_safe, false).html_safe?
    assert          bracket_or_empty("[%s]".html_safe, "<abc".html_safe, true).html_safe?
    refute_includes bracket_or_empty("[%s]".html_safe, "<abc".html_safe, true), "&lt;"
  end

  test "css_grid_input_range" do
    exp = 'input[name="artists_grid[birth_year][to]"]'
    act = css_grid_input_range(Artist, "birth_year", fromto: :to)
    assert_equal exp, act
    act = css_grid_input_range(:artists, "birth_year", fromto: :to)
    assert_equal exp, act
  end

  test "tag_pair_span" do
    exp = ['<span class="my1 my2">', '</span>']
    act = tag_pair_span(tag_class: "my1 my2")
    assert_equal exp, act
    exp = ['<em>', '</em>']
    act = tag_pair_span(tag_class: nil, tag: "em")
    assert_equal exp, act
  end

  test "safe_html_in_tagpair" do
    assert_equal "<em>abc</em>", safe_html_in_tagpair("abc".html_safe, tag_class: "", tag: "em")
    exp =  '<span class="moderator_only smaller">10 &gt; 9<br>8</span>'
    act = safe_html_in_tagpair("10 &gt; 9<br>8".html_safe, tag_class: "moderator_only smaller")
    assert_equal exp, act
  end

  test "html_consistent_or_inconsistent" do
    css_pla = CSS_CLASSES[:consistency_place]
    exp = '<span class="'+css_pla+' editor_only">(<span class="lead text-red"><strong>INCONSISTENT</strong></span>)</span>'
    assert_equal exp, html_consistent_or_inconsistent(false)

    exp = '<span class="'+css_pla+' editor_only">(<span class="lead text-red"><strong>INCONSISTENT</strong> with Event</span>)</span>'
    assert_equal exp, html_consistent_or_inconsistent(false, postfix: " with Event".html_safe)
    assert_equal "",  html_consistent_or_inconsistent(true,  postfix: " with Event".html_safe)

    opts = {print_consistent: true, with_parentheses: false, span_class: "moderator_only my_other_class"}
    exp = '<span class="'+css_pla+' moderator_only my_other_class"><span class="lead text-red"><strong>INCONSISTENT</strong></span></span>'
    act = html_consistent_or_inconsistent(false, **opts)
    assert_equal exp, act
    assert act.html_safe?
    exp = '<span class="'+css_pla+' moderator_only my_other_class">consistent</span>'
    act = html_consistent_or_inconsistent(true,  **opts)
    assert_equal exp, act
    assert act.html_safe?
  end

  test "print_1or2digits" do
    assert_equal "0.0",  print_1or2digits(0)
    assert_equal "1.0",  print_1or2digits(1)
    assert_equal "0.3",  print_1or2digits(0.3)
    assert_equal "0.33", print_1or2digits(0.33)
    assert_equal "0.33", print_1or2digits(0.3333)
    assert_equal "0.34", print_1or2digits(0.3399)
  end

  test "publicly_viewable?" do
    hvid = harami_vids(:harami_vid1)
    assert publicly_viewable?(hvid)
    assert_equal true, publicly_viewable?(hvid)
    assert publicly_viewable?(hvid, method: :show)
    assert publicly_viewable?(hvid, method: :read)
    assert publicly_viewable?(HaramiVid, method: :index)
    refute h1_note_editor_only(hvid).present?, "'Editor-only' note should not appear on public pages, but..."
    refute h1_note_editor_only(hvid, method: :show).present?

    role = Role.first
    refute publicly_viewable?(role)
    refute publicly_viewable?(role, method: :show)
    refute publicly_viewable?(role, method: :read)
    refute publicly_viewable?(Role, method: :index)

    assert publicly_viewable?(nil, permissive: true)
    assert publicly_viewable?(nil)
    assert publicly_viewable?(5 )
    assert_raises(ArgumentError){ publicly_viewable?(nil, permissive: false) }
    assert_raises(ArgumentError){ publicly_viewable?(  5, permissive: false) }
  end

  private
end

