# coding: utf-8
require "test_helper"

class ModuleUrlUtilTest < ActiveSupport::TestCase
  include ModuleUrlUtil

  test "ModuleUrlUtil.normalized_url" do
    s = "example.com/abc?q=1&r=2#xyz"
    assert_equal s, normalized_url("ftp://www."+s)  # Scheme "ftp://" is also removed in this normalization  # Used in Url
    assert_equal "www.example.com", normalized_url("ftp://www."+s, with_scheme: false, with_www: true, with_path: false, truncate_trailing_slashes: true, with_query: false, with_fragment: false, delegate_special: false)  # used in Domain
    s2= "example.com///abc?q=1&r=2#xyz"
    assert_equal "ftp://"+s, normalized_url("ftp://www."+s, with_scheme: true)  # Extra forward-slashes removed.
    assert_equal "ftp://"+s, normalized_url("ftp://www."+s, with_scheme: true, truncate_trailing_slashes: true)

    s = "www.x/invalid/"
    assert_equal s, normalized_url(s)

    s = "http://WWW.Abc.COM///"
    assert_equal "abc.com", normalized_url(s), "should have no trailing slash, but..."
    # assert_equal "http://abc.com/",    normalized_url(s, with_scheme: true, truncate_trailing_slashes: true)
    assert_equal "http://abc.com",    normalized_url(s, with_scheme: true, trim_insignificant_prefix_slash: true,  truncate_trailing_slashes: true)
    assert_equal "http://abc.com",    normalized_url(s, with_scheme: true, trim_insignificant_prefix_slash: true,  truncate_trailing_slashes: false), "when there is no significant path component, trim_insignificant_prefix_slash=true means no slashes regardless of truncate_trailing_slashes, but..."
    assert_equal "http://abc.com/",   normalized_url(s, with_scheme: true, trim_insignificant_prefix_slash: false, truncate_trailing_slashes: true)
    assert_equal "http://abc.com///", normalized_url(s, with_scheme: true, trim_insignificant_prefix_slash: false, truncate_trailing_slashes: false)
    assert_equal "http://abc.com",    normalized_url(s, with_scheme: true, trim_insignificant_prefix_slash: false, truncate_trailing_slashes: false, with_path: false)
    assert_equal "http://www.abc.com", normalized_url(s, with_scheme: true, with_www: true)

    s = "abc.com///?q="
    # assert_equal "abc.com/?q=", normalized_url("https://abc.com/?q=", with_www: true, truncate_trailing_slashes: true)  # no "www." in the original, so no "www" in output. The trailing forward slash remains.
    assert_equal "abc.com/?q=", normalized_url("https://abc.com/?q=", with_www: true, trim_insignificant_prefix_slash: true, truncate_trailing_slashes: true)  # no "www." in the original, so no "www" in output. The trailing forward slash remains because of the query.
    assert_equal "abc.com",     normalized_url("https://abc.com/?q=", with_www: true, trim_insignificant_prefix_slash: true, truncate_trailing_slashes: true, with_query: false)

    s = "abc.com:8080/File.html?q=3&r=4#MyHeAd"
    assert_equal s, normalized_url("ftp://"+s, with_www: true, with_port: true)
    trying = "ftp://"+s.sub(/^a/){|i| "A"}
    assert_equal "ftp://Abc.com:8080/File.html?q=3&r=4#MyHeAd", trying, 'sanity check'
    assert_equal "abc.com/File.html#MyHeAd", normalized_url(trying, with_query: false), "Domain is downcased while the capital 'A' in 'Head' in the fragment should be unchanged, but..."
    assert_equal "Abc.com/File.html#MyHeAd", normalized_url(trying, with_query: false, downcase_domain: false)

    s = "www.YouTube.COM/watch?v=abcdefghi&si=12345"
    assert_equal "youtu.be/abcdefghi", normalized_url("http://"+s, with_www: true, with_path: false)  # options are ignored!
    assert_equal "www.youtube.com",    normalized_url("http://"+s, with_www: true, with_path: false, delegate_special: false)

    s = "お名前.com"
    assert_equal s,   normalized_url("www."+s+":80/")
    assert_equal s+"/abc?q", normalized_url("https://www."+s+":80/abc?q")
    assert_equal s+"/abc",   normalized_url("https://www."+s+":80/abc?q", with_query: false)
    assert_equal "a."+s,     normalized_url("https://WWW.A.%E3%81%8A%E5%90%8D%E5%89%8D.Com:80/")
    exp = "%E3%81%8A%E5%90%8D%E5%89%8D.com"
    assert_equal exp, normalized_url("https://WWW.%E3%81%8A%E5%90%8D%E5%89%8D.Com:80/", decode_all: false)
  end

  test "get_uri" do
    assert_nil  get_uri(nil)
    assert_nil  get_uri("1:234/abc/def")
    assert      get_uri("").blank?
    assert      get_uri("  \t  \n").blank?

    str = "http://example.com"
    u = get_uri(str)
    assert_equal ["http", "example.com", "", nil], [u.scheme, u.host, u.path, u.query]

    str = "sftp://example.com/"
    u = get_uri(str)
    assert_equal ["sftp", "example.com", "/", nil], [u.scheme, u.host, u.path, u.query]

    str = "http://example.com/?"
    u = get_uri(str)
    assert_equal ["http", "example.com", "/", ""], [u.scheme, u.host, u.path, u.query]  # if there is a preceding "?", the query may be a blank String but non-nil.

    str = "example.com:80/abc/def?q=a&r=3#xy"
    u = get_uri(str)
    assert_equal ["https", "example.com", 80, "/abc/def", "q=a&r=3", "xy"], [u.scheme, u.host, u.port, u.path, u.query, u.fragment]

    str = "お名前.com:80"
    assert(u = get_uri(str))
    assert_equal ["https", "お名前.com", 80, "", nil, nil], [u.scheme, u.host, u.port, u.path, u.query, u.fragment]

    ###### This case is not tested because the result does not matter!
    # str = "urn:isbn:0451450523"  # a valid URI
    # u = get_uri(str)
    # assert_equal ["https", "urn:isbn", 451450523, "", nil, nil], [u.scheme, u.host, u.port, u.path, u.query, u.fragment]  # no path but a significant port (BECAUSE "https://" is internally prepended!)
  end

  test "valid_url_like?" do
    refute valid_url_like?("")
    refute valid_url_like?("https")
    refute valid_url_like?("https//")
    refute valid_url_like?("https//localhost")
    refute valid_url_like?("https//localhost:80")
    assert valid_url_like?("https://www.example.com")
    assert valid_url_like?("sftp://www.example.com")
    assert valid_url_like?("www.example.com")
    assert valid_url_like?("www.example.com/")
    assert valid_url_like?("www.example.com:80/")
    assert valid_url_like?("www.example.com/abc/def?q=2&r=4#abc")
    # refute valid_url_like?("www.example.com/abc/def??q=2")  # returns true.
    assert valid_url_like?("https://お名前.com")
    assert valid_url_like?("お名前.com")
    assert valid_url_like?("お名前.com:80/abc")
    refute valid_url_like?("https://www.x/this/is/invalid")
    refute valid_url_like?("http://:5984/asdf")    # though a valid URI; cf. https://stackoverflow.com/questions/1805761/how-to-check-if-a-url-is-valid#comment9855771_1805788
    refute valid_url_like?("urn:isbn:0451450523")  # though a valid URI; cf. https://stackoverflow.com/a/16359999/3577922
    refute valid_url_like?("https://urn:isbn:0451450523")
  end

  test "valid_domain_like?" do
    refute valid_domain_like?("")
    refute valid_domain_like?("  \t \n  ")
    refute valid_domain_like?("https")
    refute valid_domain_like?("https//")
    refute valid_domain_like?("https//localhost")
    refute valid_domain_like?("https//localhost:80")
    assert valid_domain_like?("https://www.example.com")
    assert valid_domain_like?("sftp://www.example.com")
    assert valid_domain_like?("www.example.com")
    assert valid_domain_like?("www.example.com/")
    assert valid_domain_like?("www.example.com:80/")
    refute valid_domain_like?("www.example.com/abc/def?q=2&r=4#abc")
    refute valid_domain_like?("www.example.com/abc/def??q=2")
    refute valid_domain_like?("www.example.com/?q=2&r=4#abc")
    refute valid_domain_like?("www.example.com/abc#xy")
    refute valid_domain_like?("www.example.com/#xy")
    assert valid_domain_like?("https://お名前.com")
    assert valid_domain_like?("お名前.com")
    assert valid_domain_like?("WWW.お名前.COM")
    assert valid_domain_like?("12.34.56.78")
    refute valid_domain_like?("http://:5984/asdf")    # though a valid URI; cf. https://stackoverflow.com/questions/1805761/how-to-check-if-a-url-is-valid#comment9855771_1805788
    refute valid_domain_like?("urn:isbn:0451450523")  # though a valid URI; cf. https://stackoverflow.com/a/16359999/3577922
    refute valid_domain_like?("https://urn:isbn:0451450523")
  end

  test "encoded_case_sensitive_domain" do
    org = "WWW.音.Abc.楽.ORG"
    exp = "www.%E9%9F%B3.abc.%E6%A5%BD.org"
    assert_equal exp, encoded_case_sensitive_domain(org)

    assert_equal "www.音.abc.楽.org", downcased_domain(org)
    
    org = "WWW.%E9%9F%B3.Abc.楽.ORG"
    assert_equal "www.%E9%9F%B3.abc.楽.org", downcased_domain(org)
  end

  test "extract_raw_url_like_strings" do
    strin = 'x\nhttp://example.com\nyoutu.be/XXX?t=53 [https://naiyo] www.abc.org/?q=1&r=2#X <a href="http://z.com/j">Ignored</a> [ignore this](http://y.com/k) <http://picked-up.com/ttt> https://t.co/#X'

    exp1 = ["http://example.com", "youtu.be/XXX?t=53", "https://naiyo", "www.abc.org/?q=1&r=2#X", "http://picked-up.com/ttt", "https://t.co/#X"]
    assert_equal exp1, extract_raw_url_like_strings(strin)


    exp2 = [["http://example.com",             exp1[0]],
            ["https://youtu.be/XXX?t=53",      exp1[1]],
            ["https://www.abc.org/?q=1&r=2#X", exp1[3]],
            [exp1[4],                          exp1[4]],
            [exp1[5],                          exp1[5]]]
    assert_equal exp2, extract_url_like_string_and_raws(strin)

    assert_equal [], extract_url_like_string_and_raws(nil)
  end

  test "decoded_urlstr_if_encoded" do
    dec = "https://example.com/"
    assert_equal dec, encoded_urlstr_if_decoded(dec)

    dec = "https://ja.wikipedia.org/wiki/さくら_(タレント)"
    enc = "https://ja.wikipedia.org/wiki/%E3%81%95%E3%81%8F%E3%82%89_(%E3%82%BF%E3%83%AC%E3%83%B3%E3%83%88)"
    assert_equal enc, encoded_urlstr_if_decoded(dec)
    assert_equal enc, encoded_urlstr_if_decoded(enc)
  end
end
