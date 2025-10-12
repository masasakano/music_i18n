# coding: utf-8

# Class to represent 1 parameter in a channel at a remote platform
class PrmChannelRemote
  include ModuleYoutubeApiAux
  extend ModuleYoutubeApiAux

  # A soft of ID, one of machine-ID, human-readable ID (@handle), name
  attr_accessor :val

  # Type of @val; one of :id_at_platform, :id_human_at_platform, :auto
  attr_accessor :kind

  # Platform. :youtube only so far.
  attr_accessor :platform

  # Either nil or Google::Apis::YoutubeV3::Channel
  attr_accessor :yt_channel

  # Kind parameter of this class to Youtube-Ruby-API filter keyword
  KIND2YTFILTER = {
    id_at_platform: "id",
    id_human_at_platform: "for_handle",
  }

  # Simple basic constructor
  #
  # @param val [String] main parameter
  # @param kind: [String, Symbol] One of :id_at_platform, :id_human_at_platform, :id_video, :unknown
  #    :id_video means the ID is (or looks like) the Youtube video ID (of supposedly the channel of interest)
  # @param platform: [String, Symbol] :youtube etc
  # @param yt_channel: [Google::Apis::YoutubeV3::Channel, NilClass]
  def initialize(val, kind: :unknown, platform: :youtube, yt_channel: nil)
    @val = val
    @kind = kind.to_sym
    @platform = platform.to_s.downcase.to_sym
    @yt_channel = yt_channel
  end

  def validated?
    !!@yt_channel
  end

  # @return [String, NilClass] Either "id" or "for_handle", or nil if not found.
  def yt_filter_kwd
    case @kind
    when :id_at_platform, :id_human_at_platform
      KIND2YTFILTER[@kind]  # defined in ModuleYoutubeApiAux
    else
      # raise "@kind (=#{kind}) is neither :id_at_platform nor :id_human_at_platform, and hence cannot determine the youtube filter keyword."
      nil
    end
  end

  # Alternative constructor of {PrmChannelRemote}, determines the ID from URI etc.
  #
  # This is a simple constructor, which does NOT access or use Youtube API.
  # kind is deetrmined solely based on the given String.
  #
  # If the given argument is not for Youtube, the directory part is returned,
  # and the returned String has a singleton method platform so that
  #   ret = get_yt_video_id("https://www.eample.com/xyz")
  #   ret == "xyz"
  #   ret.platform == "example.com"
  #
  # @param str_in [String] e.g., "xyz123abc", "https://www.youtube.com/channel/xyz123abc".
  # @param platform_fallback_non_uri: [String, Symbol] Recommended to be :youtube. This is only used for the non-URI like str_in like "abcdef", which may simply mean a Channel ID String.
  # @return [PrmChannelRemote] For unrecognizable URI, the platform of the returned object is
  #   the hostname String bar the preceding "www", e.g., "example.com" for "http://www.example.com/abc?x=y"
  def self.new_from_id_or_uri(str_in, platform_fallback_non_uri: :youtube)
    new_platform = 
      if str_in.include?("/")
        ApplicationHelper.guess_site_platform(str_in)
      else
        platform_fallback_non_uri.to_sym
      end

    uri = ApplicationHelper.parsed_uri_with_or_not(str_in) # => URI object.
    # "www.SOMETHING" or "youtu.be/abc" is regarded as a URI, so uri.path is significant,
    # whereas "y.com/abc" is not.
    # NOT: uri.path may well (and validly) be "/watch" (if str_in == "https://www.youtube.com/?v=abcde")

    if uri.host.blank?
      # Not a URI
      if :youtube == new_platform && "@" == uri.path[0,1] && !str_in.include?("?")
        # new_platform must be the given platform_fallback_non_uri
        return new(str_in, kind: :id_human_at_platform, platform: new_platform)
      else
        # Note uri.path is not appropriate, as the query-like part may be dropped.
        return new(str_in, kind: :unknown,              platform: new_platform)
      end
    end

    # str_in is a URI. Hence if it is non-Youtube, no need of further checking.
    if :youtube != new_platform
      return new(str_in, kind: :unknown, platform: new_platform)
    end

    # Youtube-Channel-like URI; the query part should be ignored.
    if uri.path.size > 2 && "/@" == uri.path[0..1] && !uri.path[2..-1].include?("/")
      return new(uri.path[1..-1], kind: :id_human_at_platform, platform: new_platform)  # query part is dropped.
    elsif %r@\A/channel/([^/]+)\Z@ =~ uri.path
      return new($1,              kind: :id_at_platform,       platform: new_platform)
    end

    id_video = ApplicationHelper.get_id_youtube_video(str_in)
    if id_video != str_in
      return new(id_video, kind: :id_video, platform: new_platform)
    end
 
    new(str_in, kind: :unknown, platform: new_platform)
  end

  # Alternative constructor of {PrmChannelRemote}, determines the ID from URI etc.
  #
  # If uri is PrmChannelRemote, this may ignore PrmChannelRemote.kind
  # unless thir routine fails to determine the kind.
  #
  # This does NOT validate the ID unless it has to so as to work out the +kind+.
  #
  # @param uri_str [String]  either (Youtube Channel or Video) ID or URI
  # @param platform_fallback: [String, Symbol] :youtube etc. fallback platform in case it cannot be determined from uri_str
  # @param normalize: [Boolean] If true (def: false), the best guess is returned,
  #   using Google-Youtbe API, possibly multiple times.
  #   Basically, this works as a pre-processor of {PrmChannelRemote.new_normalized}
  #   to minimize the repeated calling of Google-Youtube API, and also this never returns nil
  #   unlike the said method.
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [PrmChannelRemote] ret.val => ID-in-String, ret.kind => :id_at_platform etc.
  def self.new_from_any(uri_str, platform_fallback: :youtube, normalize: false, use_cache_test: false)
    pcr_tmp = new_from_id_or_uri(uri_str, platform_fallback_non_uri: platform_fallback)
    if !normalize || pcr_tmp.val.include?("/") || # the latter should never happen in practice.
       :youtube != pcr_tmp.platform ||
       [:id_at_platform, :id_human_at_platform].include?(pcr_tmp.kind.to_sym) 
      return pcr_tmp
    end

    # Now, (valid) pcr_tmp.val is guaranteed to be a non-URI like String, which may be either :video for sure or :unknown (either a channel or video).
    # It should never be prefixed with "@" here (because they have been already processed).
    # All valid non-youtube URI Strings should have been processed above.
    ret = new_normalized(pcr_tmp, use_cache_test: use_cache_test)
    ret || pcr_tmp
  end


  # Constructor of "normalized" validated {PrmChannelRemote}
  #
  # uri_in can be an ID or URI for a Channel or a video of the Channel.
  #
  # This always validates the result from Google-Youtube API (or its cached object).
  #
  # This method assumes platform is :youtube, and returns as such.
  #
  # @param pcr [PrmChannelRemote]  String of the ID (never URI as long as it is a valid one, be it for Youtube or other sites; see {PrmChannelRemote.new_from_any}). It should never be prefixed with "@".
  # @param definitely_video: [Boolean] true (Def: false) if the ID is definitely for a Video.
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [PrmChannelRemote, NilClass] ret.val => ID-in-String, ret.kind => :id_at_platform etc.
  def self.new_normalized(pcr, uri: nil, definitely_video: false, use_cache_test: false)
    set_youtube if !@youtube  # sets @youtube; defined in ModuleYoutubeApiAux

    ## handles the case of uri being a URI for a Video (up to two calls of Google-Youtube-API)
    if(:id_video == pcr.kind.to_sym)  # Only when it is certain to be video, this is run first, because otherwise pcr is more likely to be a Channel ID.
      ret_pcr = channel_from_video_str(pcr.val, use_cache_test: use_cache_test)
      return ret_pcr  # can be nil.
    end

    ## handles the case of uri being a Youtube ID for Channel,
    # making zero to two calls of Google-Youtube-API
    yt_chan = get_yt_channel_from_pcr(pcr, use_cache_test: use_cache_test)  # defined in ModuleYoutubeApiAux

    if yt_chan
      # Even when id_human_at_platform (Youtube: for_handle) matches, PrmChannelRemote for
      # id_at_platform (Youtube: id) is returned. It is a bit tricky to hold the information.
      return new(yt_chan.id, kind: :id_at_platform, platform: :youtube, yt_channel: yt_chan)
    end

      # Tries the Video-ID case, making up to two calls of Google-Youtube-API
    ret_pcr = channel_from_video_str(pcr.val, use_cache_test: use_cache_test)
    ret_pcr  # can be nil

  end  # def self.new_normalized

  # Returns PrmChannelRemote from the Youtube-ID (not URI) of a video in the channel.
  #
  # @param yid_video [String] Youtube-ID (not URI) of a video
  # @param yt_channel: [Google::Apis::YoutubeV3::Channel, NilClass] This has, if specified, the highest priority and is used first.
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [PrmChannelRemote, NilClass] ret.val => ID-in-String, ret.kind => :id_at_platform etc.
  def self.channel_from_video_str(yid_video, platform: :youtube, use_cache_test: false)
    set_youtube if !@youtube  # sets @youtube; defined in ModuleYoutubeApiAux
    yt_vid = get_yt_video(yid_video, set_instance_var: false, model: false, use_cache_test: use_cache_test) # sets @yt_video; defined in ModuleYoutubeApiAux
    return if !yt_vid  # yid_video is NOT an Youtube-Video ID.

    Rails.logger.info "NOTE(#{File.basename __FILE__}:self.#{__method__}): In guessing a Channel-ID, obtained Youtube Video of ID=#{yt_vid.id.inspect} title=#{yt_vid.snippet.title.inspect}" # +" (use_cache_test=#{use_cache_test.inspect})"

    # Platform is guaranteed to be Youtube
    yt_chan = get_yt_channel(yt_vid.snippet.channel_id, kind: "id_at_platform", set_instance_var: false, use_cache_test: use_cache_test) # setting @yt_channel; defined in ModuleYoutubeApiAux

    if yt_chan
      return self.new(yt_chan.id, kind: :id_at_platform, platform: :youtube, yt_channel: yt_chan)
    else
      raise "Youtube Channel is not found from its Video. This should never happen, unless the Internet is connection is unstable. yt_video=#{yt_vid.inspect}"
    end
  end
end

