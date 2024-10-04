# -*- coding: utf-8 -*-

# Common module to implement "self.primary" for {Artist} and similar
#
# @example
#   include ModuleYoutubeApiAux
#   ChannelOnwer.primary  # => primary ChannelOnwer
#
module ModuleYoutubeApiAux
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  include ApplicationHelper

  # Seeds-related constant
  SEEDS_YOUTUBE = {
    channel: {
      harami: {
        id: "UCr4fZBNv69P-09f98l7CshA",  # == channels(:channel_haramichan_youtube_main).id_at_platform  (in Test)
        basename: "youtube_channel_harami.marshal",
      }.with_indifferent_access,
    }.with_indifferent_access,
    video: {
      zenzenzense: {
        id: "hV_L7BkwioY",  # == harami1129s(:harami1129_zenzenzense1).link_root  (in Test)
        basename: "youtube_zenzenzense.marshal",
      }.with_indifferent_access,
    }.with_indifferent_access,
  }.with_indifferent_access

  module ClassMethods
  end

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
  # @param yid [String]
  # @param filter_kind: [String, Symbol] what yid means: either "id" or "forHandle". Else :auto to determine automatically (in practice, this attempts both).
  # @param youtube: [Google::Apis::YoutubeV3]
  # @param set_instance_var: [Boolean] if true (Def), @yt_channel is set (possibly overwritten).
  # @return [Google::Apis::YoutubeV3::Channel, NilClass]
  def get_yt_channel(yid, filter_kind: nil, youtube: @youtube, set_instance_var: true)
    yt_channel = nil
    ((:auto == filter_kind) ? ["id", "for_handle"] : [filter_kind]).each do |eaf|
      hsopts = {:hl => "en", eaf.to_sym => yid}
      yt_channel = youtube.list_channels("snippet", **hsopts)
      break if yt_channel
    end

    ret = (yt_channel ? yt_channel.items[0] : nil)
    @yt_channel = ret if set_instance_var
    ret
  end


  # Returns a Youtube video ID, simply based on the given URI.
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
  # If use_cache_test is specified and ENV["UPDATE_YOUTUBE_MARSHAL"] is set,
  # the test data in /fixture/data is updated.
  #
  # @param yid [String, #uri] e.g., "xyz123abc", "https://youtu.be/xyz123abc", HaramiVid. The URI can be in almost any form for Youtube.
  # @param filter_kind: [String, Symbol] what yid means: either "id" or "forHandle". Else :auto to determine automatically (in practice, this attempts both).
  # @param youtube: [Google::Apis::YoutubeV3]
  # @param set_instance_var: [Boolean] if true (Def), @yt_video is set (possibly overwritten).
  # @param model: [ActiveRecord, TrueClass, NilClass] if non-nil and if an error is raised, an error is added to either this model or yid (if this value is True and yid is ActiveRecord).
  # @param use_cache_test: [Boolean] if true, 
  # @return [Google::Apis::YoutubeV3::Video, NilClass]
  def get_yt_video(yid_in, filter_kind: "id", youtube: @youtube, set_instance_var: true, model: true, use_cache_test: false)
    return _return_error_in_get_yt_video(yid_in, set_instance_var: set_instance_var, model: model) if yid_in.respond_to?(:channel) && (chan=yid_in.channel) && chan.respond_to?(:channel_platform) && (plat=chan.channel_platform) && "youtube" != plat.mname.downcase  # returns nil if ChannelPlatform is NOT youtube

    yid = get_yt_video_id(yid_in)

    if yid.blank? || yid.respond_to?(:platform) && (:youtube != yid.platform)
      # not Youtube video or ID not found. Return nil.
      return _return_error_in_get_yt_video(yid_in, set_instance_var: set_instance_var, model: model)
    end

    ytret = nil
    if use_cache_test && [SEEDS_YOUTUBE[:video][:zenzenzense][:id]].include?(yid)
      ytret, fullpath = _get_youtubeitem_fullpath(SEEDS_YOUTUBE[:video][:zenzenzense][:basename])
    end

    ytret ||= ((yt=@youtube.list_videos(%w(snippet contentDetails), id: yid, hl: "en")) ? yt.items[0] : nil)  # maxResults is invalid with "id"
    _may_update_youtube_marshal(ytret, fullpath) if ytret && fullpath ## i.e., if use_cache_test is given AND Youtube-ID satisfies the condition AND fullpath is obtained.
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

    # Returns 2-element Array of @youtube.list_videos and fullpath, if recovering them from marshalled
    #
    # @param root_kwd [String] root filename for the marshal-led data.
    # @return [Array<Hash,String,NilClass>] 2-element Array of [Hash(Google::Apis::YoutubeV3), String(full-path)] or [nil, nil]
    def _get_youtubeitem_fullpath(root_kwd)
      return [nil, nil] if !@use_cache_test 

      fullpath = get_fullpath_test_data(root_kwd)  # defined in application_helper.rb
      #fullpath = get_fullpath_test_data(/^#{Regexp.quote(root_kwd)}/)  # defined in application_helper.rb
      return [nil, nil] if !fullpath

      [Marshal.load(IO.read(fullpath)), fullpath]
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
      return nil if !(fullpath && is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL"))
      open(fullpath, "w"){|io|
        io.write(Marshal.dump(yt_vid))
      }
      return fullpath
    end

end
