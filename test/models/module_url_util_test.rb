require "test_helper"

class ModuleUrlUtilTest < ActiveSupport::TestCase
  include ModuleUrlUtil

  test "ModuleUrlUtil.normalized_url" do
    s = "example.com/abc?q=1&r=2#xyz"
    assert_equal s, normalized_url("ftp://www."+s)  # Scheme "ftp://" is also removed in this normalization  # Used in Url
    assert_equal "www.example.com", normalized_url("ftp://www."+s, with_scheme: false, with_www: true, with_path: false, with_extra_trailing_slash: true, with_query: false, with_fragment: false, delegate_special: false)  # used in Domain
    s2= "example.com///abc?q=1&r=2#xyz"
    assert_equal "ftp://"+s, normalized_url("ftp://www."+s, with_scheme: true)  # Extra forward-slashes removed.
    assert_equal "ftp://"+s, normalized_url("ftp://www."+s, with_scheme: true, with_extra_trailing_slash: true)

    s = "www.x/invalid/"
    assert_equal s, normalized_url(s)

    s = "http://WWW.ABC.COM//"
    assert_equal "abc.com", normalized_url(s), "should have no trailing slash, but..."
    assert_equal "http://abc.com/",    normalized_url(s, with_scheme: true, with_extra_trailing_slash: true)
    assert_equal "http://www.abc.com", normalized_url(s, with_scheme: true, with_www: true)

    s = "abc.com///?q="
    assert_equal "abc.com/?q=", normalized_url("https://abc.com/?q=", with_www: true, with_extra_trailing_slash: true)  # no "www." in the original, so no "www" in output. The trailing forward slash remains.

    s = "abc.com:8080/File.html?q=3&r=4#MyHead"
    assert_equal s, normalized_url("ftp://"+s, with_www: true, with_port: true)
    assert_equal "abc.com/File.html#MyHead", normalized_url("ftp://"+s.sub(/^a/){|i| "A"}, with_query: false)

    s = "www.YouTube.COM/watch?v=abcdefghi&si=12345"
    assert_equal "youtu.be/abcdefghi", normalized_url("http://"+s, with_www: true, with_path: false)  # options are ignored!
    assert_equal "www.youtube.com",    normalized_url("http://"+s, with_www: true, with_path: false, delegate_special: false)
  end

  test "scheme_and_uri_string" do
    assert_equal "https://example.com/abc?q=",     scheme_and_uri_string("example.com/abc?q=").join
    assert_equal %w(https :// example.com/abc?q=), scheme_and_uri_string("example.com/abc?q=")
    assert_equal %w(https :// example.com/abc?q=), scheme_and_uri_string("https://example.com/abc?q=")
    assert_equal   %w(ftp :// example.com/abc?q=), scheme_and_uri_string("ftp://example.com/abc?q=")
    url = "example.com/new-poly///"
    assert_equal ["https", "://", url], scheme_and_uri_string(url)
    url = "example.co/new-poly/"
    assert_equal ["https", "://", url], scheme_and_uri_string(url)
    url = "wrong.x/some"
    assert_equal ["",      "",    url], scheme_and_uri_string(url)
  end

end
