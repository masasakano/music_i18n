# coding: utf-8

require 'test_helper'

# NOTE1: For full tests, run this with ENV["SKIP_YOUTUBE_MARSHAL"]=1
#   which may call the Google-Youtube API a score of times or so.
#
# NOTE2: For these tests, you need an Internet connection, as this uses a few
#   API accesses, even with ENV["SKIP_YOUTUBE_MARSHAL"] is "0" or undefined,
#   because this tries to access Youtube-Channel-API with an ID of a video,
#   which obviously does not exist in the marshal. Specifically, The method
#   PrmChannelRemote.new_from_any calls PrmChannelRemote.new_normalized
#   which *first* tried to retrieve the Youtube-Data with a raw ID assuming it
#   to be the Channel-API, as it should be, before the fallback routine
#   successfully finds the marshal data of the Youtube-Video.
class PrmChannelRemoteTest < ActiveSupport::TestCase

  Klass = PrmChannelRemote

  setup do
    #@use_cache_test = is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL")
    @use_cache_test = true
  end

  test "new" do
    pcr = PrmChannelRemote.new("abc", kind: :unknown, platform: :youtube, yt_channel: nil)
    assert_equal "abc", pcr.val
    assert_equal :unknown, pcr.kind
    refute  pcr.validated?
    assert_nil  pcr.yt_channel
  end

  test "yt_filter_kwd" do
    pcr = PrmChannelRemote.new("abc", kind: :unknown, platform: :youtube, yt_channel: nil)
    assert_nil  pcr.yt_filter_kwd

    pcr = PrmChannelRemote.new("abc", kind: :id_at_platform, platform: :youtube, yt_channel: nil)
    assert_equal :id_at_platform, pcr.kind
    assert_equal "id", pcr.yt_filter_kwd
  end

  test "new_from_any 1" do
    uri_in = "abcsde"
    pcr = Klass.new_from_any(uri_in, platform_fallback: :naiyo, normalize: false, use_cache_test: false)
    assert_equal uri_in, pcr.val
    assert_equal :unknown, pcr.kind
    assert_equal :naiyo,   pcr.platform
    refute  pcr.validated?

    uri2 = "https://y.com/ab?cdef=0"
    pcr = Klass.new_from_any(uri2, platform_fallback: :naiyo, normalize: false, use_cache_test: @use_cache_test)
    assert_equal uri2,     pcr.val
    assert_equal :unknown, pcr.kind
    assert_equal  "y.com", pcr.platform.to_s
    assert_equal :"y.com", pcr.platform  ### This may change in the future!!!
    refute  pcr.validated?

    pcr = Klass.new_from_any(uri_in, platform_fallback: :youtube, normalize: false, use_cache_test: @use_cache_test)
    assert_equal uri_in, pcr.val
    assert_equal :unknown, pcr.kind
    assert_equal :youtube, pcr.platform
    refute  pcr.validated?

    pcr = Klass.new_from_any("www.youtube.com/@"+uri_in, normalize: false, use_cache_test: @use_cache_test)
    assert_equal "@"+uri_in, pcr.val
    assert_equal :id_human_at_platform, pcr.kind
    assert_equal :youtube, pcr.platform
    refute  pcr.validated?

    pcr = Klass.new_from_any("www.youtube.com/channel/"+uri_in, normalize: false, use_cache_test: @use_cache_test)
    assert_equal uri_in, pcr.val
    assert_equal :id_at_platform, pcr.kind
    assert_equal :youtube, pcr.platform
    refute  pcr.validated?

    ## FROM here: normalize: true

    kwd = channels(:channel_haramichan_youtube_main).id_at_platform  # UCr4fZBNv69P-09f98l7CshA
    pcr = Klass.new_from_any(kwd, normalize: true, use_cache_test: @use_cache_test)
    assert_equal kwd, pcr.val
    assert_equal :id_at_platform, pcr.kind
    assert_equal :youtube, pcr.platform
    assert  pcr.yt_channel
    assert  pcr.validated?

    kwd = channels(:channel_haramichan_youtube_main).id_human_at_platform  # @haramipiano_main
    kwd4id = channels(:channel_haramichan_youtube_main).id_at_platform
    pcr = Klass.new_from_any(kwd.sub(/^@?/, ""), normalize: true, use_cache_test: @use_cache_test)
    assert_equal kwd4id, pcr.val
    assert_equal :id_at_platform, pcr.kind  # Regardless of which matches, this (i.e., for "ID") is returned.
    # assert_equal kwd, pcr.val
    # assert_equal :id_human_at_platform, pcr.kind, "kwd=#{kwd.inspect}"  # not now, though it may change in the future.
    assert_equal :youtube, pcr.platform
    assert  pcr.yt_channel
    assert  pcr.validated?

    kwd = channels(:channel_haramichan_youtube_main).id_human_at_platform  # haramipiano_main
    pcr = Klass.new_from_any(kwd.sub(/^@?/, "@"), normalize: true, use_cache_test: @use_cache_test)  # @haramipiano_main
    assert_equal kwd, pcr.val                     # Because API is not accessed
    assert_equal :id_human_at_platform, pcr.kind  # Because API is not accessed
    assert_equal :youtube, pcr.platform
    refute  pcr.yt_channel
    refute  pcr.validated?

  end
  test "new_from_any 2" do
    # Youtube Video ID given (both a bare ID and URI)
    id_chan = channels(:channel_haramichan_youtube_main).id_at_platform  # UCr4fZBNv69P-09f98l7CshA
    vid = "hV_L7BkwioY"  # HARAMIchan Zenzenzense; harami1129s(:harami1129_zenzenzense1).link_root
    [vid, "https://www.youtube.com/watch?v="+vid].each do |ekwd|
      pcr = Klass.new_from_any(ekwd, normalize: true, use_cache_test: @use_cache_test)  # Video
      assert_equal id_chan, pcr.val
      assert_equal :id_at_platform, pcr.kind
      assert_equal :youtube, pcr.platform
      assert  pcr.yt_channel
      assert  pcr.validated?, "Every time @yt_channel is loaded, it should be (regarded as) validated."
    end

    ## WARNING: This always accesses Google Youtube API.
    if is_env_set_positive?("SKIP_YOUTUBE_MARSHAL") # defined in ApplicationHelper
      # wrong ID
      kwd = "naiyo"*5  # The "naiyo" is an existing Youtube ID or handle.
      pcr = Klass.new_from_any(kwd, normalize: true, use_cache_test: @use_cache_test)
      assert_equal kwd, pcr.val
      assert_equal :unknown, pcr.kind
      assert_equal :youtube, pcr.platform
      refute  pcr.yt_channel
      refute  pcr.validated?, "With the prefix @ given, @yt_channel is not obatained in default, and hence it should not be validated (at the PrmChannelRemote level, because it is a container)."
    end


    ####......
  end


  private
end

