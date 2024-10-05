# coding: utf-8

# Class to represent 1 parameter in a channel at a remote platform
class PrmChannelRemote
  include ModuleYoutubeApiAux

  # A soft of ID, one of machine-ID, human-readable ID (@handle), name
  attr_accessor :val

  # Type of @val; one of :id_at_platform, :id_human_at_platform, :auto
  attr_accessor :kind

  # Platform. :youtube only so far.
  attr_accessor :platform

  # If true, @kind has been validated.
  attr_accessor :validated

  # Either nil or Google::Apis::YoutubeV3::Channel
  attr_accessor :yt_channel

  # Kind parameter of this class to Youtube-Ruby-API filter keyword
  KIND2YTFILTER = {
    id_at_platform: "id",
    id_human_at_platform: "for_handle",
  }

  # @param val [String] main parameter
  # @param kind: [String, Symbol] One of :id_at_platform, :id_human_at_platform, :auto, :unknown
  # @param platform: [String, Symbol] :youtube etc
  # @param fetch: [Boolean] If true (def: false), this determines @kind with Youtube-API
  # @param yt_channel: [Google::Apis::YoutubeV3::Channel, NilClass]
  def initialize(val, kind: , platform: :youtube, fetch: false, validated: false, yt_channel: nil)
    @val = val
    @kind = kind.to_sym
    @platform = platform.to_s.downcase.to_sym
    @validated = validated
    @yt_channel = yt_channel

    if fetch && :youtube != @platform
      raise ArgumentError, "Platform must be :youtube to 'fetch'. val=#{val.inspect}"
    end
  end

  # @return [String, NilClass] Either "id" or "for_handle", or nil if not found.
  def yt_filter_kwd
    case @kind
    when :id_at_platform, :id_human_at_platform
      KIND2YTFILTER[@kind]
    else
      # raise "@kind (=#{kind}) is neither :id_at_platform nor :id_human_at_platform, and hence cannot determine the youtube filter keyword."
      nil
    end
  end

  # Determines the ID, returning a new {PrmChannelRemote}
  #
  # If uri is PrmChannelRemote, this may ignore PrmChannelRemote.kind
  # unless thir routine fails to determine the kind.
  #
  # @param uri_in [String, PrmChannelRemote]
  # @param platform: [String, Symbol] :youtube etc
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [PrmChannelRemote] ret.val => ID-in-String, ret.kind => :id_at_platform etc.
  def self.extract_id_from_uri(uri_in, platform: :youtube, fetch: false, use_cache_test: false)
    uri_str = (uri_in.respond_to?(:val) ? uri_in.val : uri_in.to_s)

    new_platform = 
      if uri_str.include?("/")
        ApplicationHelper.guess_site_platform(uri_str)
      else
        platform
      end

    uri = ApplicationHelper.parsed_uri_with_or_not(uri_str) # => URI object.
    # "www.SOMETHING" or "youtu.be/abc" is regarded as a URI, whereas "y.com/abc" is not.

    if :youtube != new_platform
      return self.new([uri.path, uri.query].join("?"), kind: :unknown, platform: new_platform, fetch: false)
    end

    if !uri.path.include?("/") && "@" == uri.path[0,1]
      # i.e., like "https://www.youtube.com/@haramipiano_main"
      return self.new(uri.path[1..-1], kind: :id_human_at_platform, platform: new_platform, fetch: false)
    elsif %r@channel/([^/?]+)@ =~ uri.path
      # i.e., like "https://www.youtube.com/channel/UCr4fZBNv69P-09f98l7CshA"
      return self.new($1, kind: :id_at_platform, platform: new_platform, fetch: false)
    end

    # URI is either a raw String for Channel-ID or Video-ID or URI for a Video. We must guess to know it for sure.
    if !fetch || (!uri.host && uri.path.include?("/"))  # the latter should never happen in practice.
      return self.new([uri.path, uri.query].join("?"), kind: :unknown, platform: new_platform, fetch: false)
    end

    # Tries a Channel (up to two calls of Google-Youtube-API)
    yt_chan =
      if uri_in.respond_to?(:yt_channel) && uri_in.yt_channel
        uri_in.yt_channel
      else
        set_youtube # sets @youtube; defined in ModuleYoutubeApiAux
        get_yt_channel(yid, filter_kind: :auto, set_instance_var: false, use_cache_test: use_cache_test)  # sets @yt_channel; defined in ModuleYoutubeApiAux
      end

    if yt_chan
      kind2ret = ((yid == yt_chan.id) ? :id_at_platform : :id_human_at_platform)
      return self.new([uri.path, uri.query].join("?"), kind: kind2ret, platform: new_platform, fetch: false, validated: true, yt_channel: yt_chan)
    end

    # Tries a Video (one call of Google-Youtube-API)
    set_youtube if !@youtube  # sets @youtube; defined in ModuleYoutubeApiAux
    yt_vid = get_yt_video(yid_in, set_instance_var: false, model: false, use_cache_test: use_cache_test) # sets @yt_video; defined in ModuleYoutubeApiAux

    if yt_vid
      yt_chan = get_yt_channel(yt_vid.snippet.channel_id, filter_kind: "id", set_instance_var: false, use_cache_test: use_cache_test) # setting @yt_channel

      if yt_chan
        return self.new(yt_chan.id, kind: :id_at_platform, platform: new_platform, fetch: false, validated: true, yt_channel: yt_chan)
      else
        raise "Youtube Channel is not found from its Video. This should never happen... yt_video=#{yt_vid.inspect}"
      end
    end

    self.new([uri.path, uri.query].join("?"), kind: :unknown, platform: new_platform, fetch: false, validated: false)
  end
end

