# -*- coding: utf-8 -*-
# require "unicode/emoji"
# require "google/apis/youtube_v3"

# Common module to implement Youtube-API-related methods
#
# @example
#   include ModuleYoutubeApiAux
#   set_youtube                   # sets @youtube
#   get_yt_video(HaramiVid.last)  # sets @yt_video
#   ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds  # => Float
#
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : In testing, if this is set, marshal-ed data are not used,
#   but it accesses the remote Google/Youtube API.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
#   If this is set, ENV["SKIP_YOUTUBE_MARSHAL"] is ignored.
#   NOTE even if this is set, it does NOT create a new one but only updates an existing one(s).
#   Use instead: bin/rails save_marshal_youtube
module ModuleYoutubeApiAux
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  include ApplicationHelper

  #module ClassMethods
  #end

  # sets @youtube
  #
  # +ENV["YOUTUBE_API_KEY"]+ must be set non-negative.
  def set_youtube
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
    @youtube.key = ENV["YOUTUBE_API_KEY"]  # or else
    if @youtube.blank?
      msg = "ERROR: ENV[YOUTUBE_API_KEY] undefined."
      logger.error()
      raise msg
    end
  end


  # Returns Youtube-Channel, setting @yt_channel (unless otherwise)
  #
  # Gets Google::Apis::YoutubeV3::Channel for "en".
  # The returned value has attributes of
  #
  # * "kind" (== "youtube#channel")
  # * "id" (=>ChannelID(String))
  # * "snippet" (Google::Apis::YoutubeV3::ChannelSnippet), which has attributes of
  #   * title
  #   * description
  #   * custom_url (=>"@haramipiano_main" not preceding with https etc),
  #   * published_at (=>DateTime?),
  #   * country (=>"JP"?),
  #   * default_language (=>"ja"?),
  #   * localized (=> {title:, description: } for "en" or its fallback.
  #   * thumbnails (=> {title:, description: } for "en" or its fallback.
  #
  # @param yid [String, PrmChannelRemote]
  # @param filter_kind: [String, Symbol] what yid means: either "id" or "forHandle". Else :auto to determine automatically (in practice, this connects to Youtube up to 2 times).
  # @param youtube: [Google::Apis::YoutubeV3]
  # @param set_instance_var: [Boolean] if true (Def), @yt_channel is set (possibly overwritten).
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [Google::Apis::YoutubeV3::Channel, NilClass]
  def get_yt_channel(yid, filter_kind: :auto, youtube: @youtube, set_instance_var: true, use_cache_test: false)
    yt_channel = nil

    yid_str = (yid.respond_to?(:gsub) ? yid : yid.val) # the latter for PrmChannelRemote

    arfilter = 
      if (:auto == filter_kind)
        if yid.respond_to?(:yt_filter_kwd) && (new_filter = yid.yt_filter_kwd) # if PrmChannelRemote
          [new_filter]
        elsif '@' == yid_str[0,1]
          ["for_handle"]
        else
          ["id", "for_handle"]
        end
      else
        [filter_kind]
      end

    arfilter.each do |eaf|
      hsopts = {:hl => "en", eaf.to_sym => yid_str}
      yt_channel = youtube.list_channels("snippet", **hsopts)
      break if yt_channel
    end

    ret = (yt_channel ? yt_channel.items[0] : nil)
    @yt_channel = ret if set_instance_var
    ret
  end


  # Returns a Youtube video ID, simply based on the given URI.
  #
  # Wrapper of {ApplicationHelper.get_id_youtube_video}
  #
  # If the given argument is not for Youtube, the directory part is returned,
  # and the returned String has a singleton method platform so that
  #   ret = get_yt_video_id("https://www.eample.com/xyz")
  #   ret == "xyz"
  #   ret.platform == "example.com"
  #
  # @param yid [String, #uri] e.g., "xyz123abc", "https://youtu.be/xyz123abc", HaramiVid. The URI can be in almost any form for Youtube.
  # @return [String] youtube video ID or basename of the URI, having a singleton method "platform"
  def get_yt_video_id(yid)
    yidstr = (yid.respond_to?(:uri) ? yid.uri : yid.strip)
    if yidstr.include?("/")
      ApplicationHelper.get_id_youtube_video(yidstr)
    else
      yidstr
    end
  end

  # Returns Youtube-Video instance, setting @yt_video in default.
  #
  # If use_cache_test is true, the cache (marshal-ed data at /test/fixtures/data
  # as specified in +ApplicationHelper::DEF_FIXTURE_DATA_DIR+) is used in principle,
  # instead of accessing remote Google/Youtube-API (as long as the cache exists,
  # which should be always the case once the cache has been created).
  # Even When +use_cache_test+ is true, if either of ENV["SKIP_YOUTUBE_MARSHAL"]
  # and ENV["UPDATE_YOUTUBE_MARSHAL"] is set positive, the marshal-ed cache is *NOT*
  # read, but this accesses the remobe Youtube-API.
  #
  # Also, if ENV["UPDATE_YOUTUBE_MARSHAL"] is set positive AND if +use_cache_test+ is true
  # the cache is updated, as long as the file already exists. In practice, this happens
  # only in the test environment (because this method is always called with +use_cache_test: false+
  # except in the test environment).
  #
  # @param yid [String, #uri] e.g., "xyz123abc", "https://youtu.be/xyz123abc", HaramiVid. The URI can be in almost any form for Youtube.
  # @param youtube: [Google::Apis::YoutubeV3]
  # @param set_instance_var: [Boolean] if true (Def), @yt_video is set (possibly overwritten).
  # @param model: [ActiveRecord, TrueClass, NilClass] if non-nil and if an error is raised, an error is added to either this model or yid (if this value is True and yid is ActiveRecord).
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [Google::Apis::YoutubeV3::Video, NilClass] This is +Google::Apis::YoutubeV3::ListVideosResponse#items[0]+
  def get_yt_video(yid_in, youtube: @youtube, set_instance_var: true, model: true, use_cache_test: false)
    return _return_error_in_get_yt_video(yid_in, set_instance_var: set_instance_var, model: model) if yid_in.respond_to?(:channel) && (chan=yid_in.channel) && chan.respond_to?(:channel_platform) && (plat=chan.channel_platform) && "youtube" != plat.mname.downcase  # returns nil if ChannelPlatform is NOT youtube

    yid = get_yt_video_id(yid_in)

    if yid.blank? || yid.respond_to?(:platform) && (:youtube != yid.platform)
      # not Youtube video or ID not found. Return nil.
      return _return_error_in_get_yt_video(yid_in, set_instance_var: set_instance_var, model: model)
    end

    ytret = nil
    if use_cache_test
      require Rails.root.join("test/helpers/marshaled")  # loads the constant MARSHALED
      ytret, fullpath = _get_youtube_marshaled_fullpath(yid, :zenzenzense, kind: :video)
      # ytret is non-nil only if yid agrees with Marshal(:zenzenzense) AND if it is for testing etc
      msg = "DEBUG: marshal was attempted to be loaded from #{fullpath.inspect}; result=#{ytret.inspect}"
      logger.debug msg
    end

    if !ytret
      logger.debug("DEBUG: accesses Google/Youtube API for Video #{yid.inspect}")
      yt = @youtube.list_videos(%w(snippet contentDetails), id: yid, hl: "en")  # maxResults is invalid with "id"
      ytret = (yt ? yt.items[0] : nil)
      msg = "DEBUG: Info of Video #{yid.inspect} was retrieved with Google/Youtube API; result=#{ytret.inspect}"
      logger.debug msg
    end

    _may_update_youtube_marshal(ytret, fullpath) ## i.e., updated if use_cache_test is true AND ENV["UPDATE_YOUTUBE_MARSHAL"] is positive AND Youtube-ID satisfies the condition AND fullpath has been obtained.
    @yt_video = ytret if set_instance_var
    ytret
  end

    
  # Return the {Channel}
  #
  # If the ID-based search over the registered {Channel}-s has failed,
  # a human-readable-ID-based search is performed. If it fails, a title-based search
  # is performed.
  #
  # @return [Channel, NilClass]
  def get_channel(snippet)
    channel = Channel.find_by(id_at_platform: snippet.channel_id)
    return _update_channel_youtube_ids(channel, snippet) if channel

    get_yt_channel(snippet.channel_id, filter_kind: "id") if !@yt_channel
    yt_handle = @yt_channel.snippet.custom_url.sub(/^@/, "")

    channel = Channel.find_by(id_human_at_platform: yt_handle)
    return _update_channel_youtube_ids(channel, snippet, yt_handle: yt_handle) if channel

    ## preforming title-based search (may wrongly identifies Channel)
    chan_platform_youtube = ChannelPlatform.select_by_translations(en: {title: 'Youtube'}).first
    channel = Channel.where(channel_platform_id: chan_platform_youtube.id).select_regex(:title, /^#{Regexp.quote(snippet.channel_title)}(\b|\s|$)/, langcode: snippet.default_language, sql_regexp: true).joins(:channel_type).order("channel_types.weight").first  # based on the human-readable Channel title.  nil is returned if not found.
    flash[:warning] ||= []

    if !channel
      msg = sprintf("Failed to find Channel with remote-IDs/handle (Youtube-ID=%s, Handle=%s).", 
                    snippet.channel_id.inspect,
                    yt_handle.inspect)
      flash[:warning] << msg
      return nil
    end

    id_defined = channel.id_at_platform.present? || channel.id_human_at_platform.present?
    strmid, strtail =
            if id_defined
              ["inconsistent with those taken from the given URI", " Processing aborted."]
            else
              ["not defined", ""]
            end
    msg = sprintf("Although there is a Channel(pID=%s) [%s] with a similar name, its remote-IDs/handle are %s (Youtube-ID=%s, Handle=%s).%s", 
                    channel.id.inspect,
                    channel.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true),
                    strmid,
                    snippet.channel_id.inspect,
                    yt_handle.inspect,
                    strtail
                 )
    flash[:warning] << msg
    return if id_defined

    return _update_channel_youtube_ids(channel, snippet, yt_handle: yt_handle)
  end

  #################
  private 
  #################

    # Adjustment 
    def _run_update_channel(result, msg_err, msg_ok=nil, model: @harami_vid)
      flash[:notice] ||= []
      if result
        flash[:notice] << msg_ok if msg_ok
        return result
      end

      model.errors.add :base, msg_err
      return result
    end

    # Updates Youtube-ID related info of the Channel
    #
    # Returns (parroting) the given Channel if everything is OK.
    # If failed to update Channel when prompted to attempt, returns nil.
    #
    # @param channel [Channel]
    # @param snippet [Google::Apis::YoutubeV3::Video, NilClass] unnecessary if @yt_channel is already set
    # @param yt_handle: [String, NilClass] Youtube channel's Handle-name.
    # @return [Channel, NilClass]
    def _update_channel_youtube_ids(channel, snippet=nil, yt_handle: nil)
      msg_err_head = sprintf("Failed to update Channel(pID=%d) for ", channel.id)
      get_yt_channel(snippet.channel_id, filter_kind: "id") if !@yt_channel
  
      if channel.id_at_platform != @yt_channel.id
        result = channel.update(id_at_platform: @yt_channel.id)
        ret = _run_update_channel(result, msg_err_head+"id_at_platform to: "+@yt_channel.id.inspect)
        return (ret ? channel : ret)
      end
 
      yt_handle ||= @yt_channel.snippet.custom_url.sub(/^@/, "")
      if channel.id_human_at_platform != yt_handle
        result = channel.update(id_human_at_platform: yt_handle)
        ret = _run_update_channel(result, msg_err_head+"id_human_at_platform to: "+yt_handle.inspect)
        return (ret ? channel : ret)
      end

      return channel
    end

    # Called from get_yt_video(), returns nil, maybe setting model.errors
    #
    # @param see #get_yt_video
    # @return [NilClass]
    def _return_error_in_get_yt_video(yid_in, set_instance_var: true, model: true)
      @yt_video = nil if set_instance_var

      return nil if !model

      mdl =
        if model.respond_to?(:errors)
          model
        elsif yid_in.respond_to?(:errors)
          yid
        else
          nil
        end
      mdl.errors.add(:base, "Non-Youtube video is unsupported.") if mdl
      return nil 
    end

    # @param root_kwd [String] root filename for the marshal-led data.
    # @return [String, NilClass] The absolute path of the existing marshal file
    def _find_marshal_fullpath(root_kwd)
      get_fullpath_test_data(root_kwd, suffixes: %w(marshal))  # defined in application_helper.rb
    end


    # Returns a marshal-ed Youtube-Video object and its marshall fullpath (for potential use of updating later)
    #
    # @param yid [String] Video ID at Youtube
    # @param data_kwds [String, Symbol, Array] like :zenzenzense or its Array; see MARSHALED (in /test/helpers/marshaled.rb)
    # @param kind [String, Symbol] either :video or :channel (or its String)
    # @return [Array<Google::Apis::YoutubeV3::Video,String,NilClass>] 2-element Array of [Apis|nil, String(full-path)|nil]
    def _get_youtube_marshaled_fullpath(yid, data_kwds, kind: :video)
      return [nil, nil] if !is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL") && is_env_set_positive?("SKIP_YOUTUBE_MARSHAL")

      [data_kwds].flatten.each do |dkwd|
        next if ![MARSHALED[:youtube][kind][dkwd][:id]].include?(yid)

        fullpath = _find_marshal_fullpath(MARSHALED[:youtube][kind][dkwd][:basename])
        next if fullpath.blank?
        # Now, a file at fullpath is guaranteed to exist (never a new file).

        return [nil, fullpath] if is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL") || is_env_set_positive?("SKIP_YOUTUBE_MARSHAL")

        logger.debug("DEBUG: loading marshall (kwd=#{dkwd.inspect}) for Video #{yid.inspect}")
        return [Marshal.load(IO.read(fullpath)), fullpath]
      end

      [nil, nil]  # Basically no Marshal-fullpath is found for the given Youtube Video-ID
    end

    # Save the marshal-led Youtube-API-Hash if all the conditions satisfy.
    #
    # The data are saved if :
    #
    # * The given +fullpath+ is present, AND
    # * +ENV["UPDATE_YOUTUBE_MARSHAL"]+ is set.
    #
    # Also, in practice, the caller should be given use_cache_test as an argument,
    # or else this method would not be called in the first place.
    #
    # @param yt_vid [Google::Apis::YoutubeV3::Video] Youtube API return
    # @param fullpath [String] to save.
    # @return [String, NilClass>] If saved, the given fullpath is returned, else nil.
    def _may_update_youtube_marshal(yt_vid, fullpath)
      return nil if !yt_vid || !fullpath || !is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL") # defined in ApplicationHelper
      msg = "NOTE: Updated #{fullpath}"
      logger.info(msg)
      puts msg
      save_marshal(yt_vid, fullpath)  # defined in application_helper.rb
      return fullpath
    end

end
