# -*- coding: utf-8 -*-
# require "unicode/emoji"
# require "google/apis/youtube_v3"

# Common module to implement Youtube-API-related methods
#
# @example
#   include ModuleYoutubeApiAux
#   set_youtube                   # sets @youtube. ENV["YOUTUBE_API_KEY"] has to be set appropriately beforehand.
#   get_yt_video(HaramiVid.last)  # sets @yt_video
#   ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds  # => Float
#
# == Marshal (cache mechanism)
#
# For Video information access, {#get_yt_video} accesses the remote YouTube API.
# Similarly, for channel information access, #{get_yt_channel} is responsible.
#
# Caching in testing works as follows
#
# * When {#get_yt_video} (or #{get_yt_channel}) is called with the optional parameter `use_cache_test: true`,
#   if searches for a Youtube cache data and uses them if found.  If not, it simply accesses remote.
#   * For example, in +get_yt_video("xyz123abc")+, where +"xyz123abc"+ is the unique Youtube ID for the video,
#     it uses the cached data if it has been already cached (see below to see what data are cached). 
#   * For this reason, testing a failure case (i.e., not finding the marshal-led data locally
#     or maybe even in a remote site) always accesses the remote.
#   * In the test environment, `use_cache_test: true` is ON in default.  Otherwise, no.
#     So, in the standard use, this always skips the cache.
# * Cached data are stored in /test/fixtures/data as specified in +ApplicationHelper::DEF_FIXTURE_DATA_DIR+.
#   * Cached data are registered in the git repository for a semi-permanent use.  Indeed, otherwise, it would not work well as a cache, depending on the environment!
# * Index (look-up table) for the cached data is defined in the hard-coded constant +MARSHALED+
#   defined in +Rails.root.join("test/helpers/marshaled")+, which is loaddd only in some specific test files
#   and only when some conditions are met (see {#get_yt_video} for example).
#   * To see what is available as the cache, see the source code of above-mentioned +MARSHALED+ or +setup+ in +/test/controllers/harami_vids/fetch_youtube_data_controller_test.rb+
# * To register a new cache data,
#   1. you must first modify the file (look-up table)
#   2. Second, run the rake task: `lib/tasks/save_marshal_youtube.rake`  (use is like: bin/rails save_marshal_youtube)
# * If you want to *update* the cache, either run the rake task or seet +ENV["UPDATE_YOUTUBE_MARSHAL"]+ and run your standard test routines that use the cached data.
# * In some testing, if you do not want to use caching, set +ENV["SKIP_YOUTUBE_MARSHAL"]+ and run the test.
# * The main module for Youtube-API interface, including caching, is +/app/controllers/concerns/module_youtube_api_aux.rbmodule_youtube_api_aux.rb+,
#   whereas the main front-end controller for it is +/app/controllers/harami_vids/fetch_youtube_data_controller.rb+
#
# If use_cache_test is true, the cache (marshal-ed data at 
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
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : In testing, if this is set, marshal-ed data are not used,
#   but it accesses the remote Google/Youtube API.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
#   If this is set, ENV["SKIP_YOUTUBE_MARSHAL"] is ignored.
#   NOTE even if this is set, it does NOT create a new one but only updates an existing one(s).
#   Use instead: bin/rails save_marshal_youtube
# * +Rails.logger+ as opposed to +logger+ is preferred, becase
#   this module is included in {PrmChannelRemote}, in which case
#   +logger+ is undefined.
#
module ModuleYoutubeApiAux
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  include ApplicationHelper
  include ModuleGuessPlace  # for guess_place

  # Kind parameter of this class to Youtube-Ruby-API filter keyword
  KIND2YTFILTER = {
    id_at_platform: "id",
    id_human_at_platform: "for_handle",  # for filter in the query.  To retrive, it is "snippet.custom_url"
  }.with_indifferent_access

  #module ClassMethods
  #end

  # sets @youtube
  #
  # Its API key is set.
  # +ENV["YOUTUBE_API_KEY"]+ must be set non-negative.
  #
  # @param set_instance_var: [Boolean] if true (Def), @youtube is set (possibly overwritten).
  # @return [Google::Apis::YoutubeV3::YouTubeService]
  def set_youtube(set_instance_var: true)
    youtube = Google::Apis::YoutubeV3::YouTubeService.new
    youtube.key = ENV["YOUTUBE_API_KEY"]  # or else
    if youtube.blank?
      msg = "ERROR: ENV[YOUTUBE_API_KEY] undefined."
      Rails.logger.error(msg)
      raise msg
    end
    @youtube = youtube if set_instance_var
    youtube
  end

  # Returns the value from Youtube-API response of Channel
  #
  # @param kind [Symbol, String] (:id_at_platform|:id_human_at_platform)
  # @param yt_channel: [Google::Apis::YoutubeV3::Channel]
  def get_id_ytresponse(kind, yt_channel: @yt_channel)
    case kind.to_sym
    when :id_at_platform
      yt_channel.id  
    when :id_human_at_platform
      yt_channel.snippet.custom_url
    else
      raise ArgumentError, "wrong kind =(#{kind.inspect})"
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
  # @param inobj [String, PrmChannelRemote, Channel]
  # @param kind: [String, Symbol] what inobj means when it is String (irrelevant for the other classes): one of %i(id_at_platform id_human_at_platform unknown). See KIND2YTFILTER for the corresponding Youtube-API filters.
  # @param youtube: [Google::Apis::YoutubeV3]
  # @param set_instance_var: [Boolean] if true (Def), @yt_channel is set (possibly overwritten).
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [Google::Apis::YoutubeV3::Channel, NilClass]
  def get_yt_channel(inobj, kind: :unknown, youtube: @youtube, set_instance_var: true, use_cache_test: false)
    if inobj.respond_to?(:gsub) || inobj.respond_to?(:val)
      # inobj is either String or PrmChannelRemote
      yt_channel = get_yt_channel_from_pcr(inobj, kind: kind, youtube: youtube, use_cache_test: use_cache_test)
      @yt_channel = yt_channel if set_instance_var
      return yt_channel
    end

    # inobj is Channel
    raise ArgumentError, "Wrong object: #{inobj.inspect}" if !inobj.respond_to?(:channel_owner_id)

    platform_this = inobj.channel_platform.mname.to_sym
    if :youtube != platform_this
      inobj.errors.add :base, "It is not a Youtube URI, and so cannot work out the platform ID."
      return
    end

    pcrs = %i(id_at_platform id_human_at_platform).map{ |eatt|
      idval = inobj.send(eatt)
      idval.present? ? PrmChannelRemote.new(inobj.send(eatt), kind: eatt, platform: inobj.channel_platform.mname.to_sym) : nil
    }.compact

    return nil if pcrs.empty?
    
    yt_channel = get_yt_channel_from_pcr(pcrs[0], youtube: youtube, use_cache_test: use_cache_test)

    # NOTE: whenever pcrs has 2-elements, the second element is Channel#id_human_at_platform
    if pcrs[1] && yt_channel.snippet.custom_url != pcrs[1].val
      msg = "ERROR: Channel#id_human_at_platform (=#{pcrs[1].val.inspect}) != Youtube-Data (=#{yt_channel.snippet.custom_url.inspect})."
      inobj.errors.add :base, msg
      Rails.logger.warn msg
      return
    end

    @yt_channel = yt_channel if set_instance_var
    yt_channel
  end  # def get_yt_channel()


  # Returns Google:...:Channel or nil, searched based on the given String keyword.
  #
  # @param pcr_or_str [PrmChannelRemote, String]
  # @param kind: [String, Symbol] One of :id_at_platform, :id_human_at_platform, :unknown (NOT :id_video). Mandatory only when pcr_or_str is String, but otherwise ignored.
  # @param youtube [Google::Apis::YoutubeV3::YouTubeService]
  # @param use_cache_test: [Boolean] if true, the cache (marshal-ed) data are used in principle (see above).
  # @return [Google::Apis::YoutubeV3::Channel, NilClass] Marshal fullpath is found at @marshal_abspaths["channel"]["id" or "for_handle"]
  def get_yt_channel_from_pcr(pcr_or_str, kind: nil, youtube: @youtube, use_cache_test: false)
    pcr = (pcr_or_str.respond_to?(:gsub) ? PrmChannelRemote.new(pcr_or_str, kind: kind) : pcr_or_str)
    if pcr.val.blank?
      raise "ERROR: pcr is strange: #{pcr.inspect}"
    end
    fullpath = nil
    youtube ||= set_youtube(set_instance_var: false)

    filters = _get_channel_filters(pcr)  #  %i(id for_handle) if pcr_or_str is String

    if use_cache_test
      require Rails.root.join("test/helpers/marshaled")  # loads the constant MARSHALED
      yt_channel, fullpath = _get_youtube_marshaled_fullpath(pcr.val, category: :channel, filters: filters)
      # yt_channel is non-nil only if pcr.val agrees with a content of defined Marshal-ed channels (in /test/helpers/marshaled.rb) AND if it is for testing etc
      # Its fullpath is @marshal_abspaths["channel"]["id"] etc.
      msg = "DEBUG: marshal was attempted to be loaded for #{pcr.val.inspect} from #{fullpath.inspect}; result=#{yt_channel.inspect.sub(/(, @description=.{40}).*(\", @title=.*, @title=)/){$1+'[...(snip)...]'+$2}}"
      Rails.logger.debug msg
      return yt_channel if yt_channel
    end

    filters.each do |eaf|
      Rails.logger.debug("DEBUG: accesses Google/Youtube API for Channel #{pcr.val.inspect}")
      hsopts = {:hl => "en", eaf.to_sym => pcr.val}
      yt_channels = youtube.list_channels("snippet", **hsopts)
      msg = "DEBUG: Info of Channel #{pcr.val.inspect} was retrieved with Google/Youtube API; result=#{yt_channels.inspect}"
      Rails.logger.debug msg
      if (yt_channels && yt_channels.items.present? && (yt_channels.page_info.total_results > 0))
        return yt_channels.items[0]
      end
      Rails.logger.debug("DEBUG: No significant channel was retrieved for #{pcr.val.inspect}")
    end
    nil
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
      ytret, fullpath = _get_youtube_marshaled_fullpath(yid, :zenzenzense, category: :video)
      # ytret is non-nil only if yid agrees with defined Marshal (i.e., :zenzenzense; see /test/helpers/marshaled.rb) AND if it is for testing etc
      msg = "DEBUG: marshal was attempted to be loaded from #{fullpath.inspect}; result=#{ytret.inspect}"
      Rails.logger.debug msg
    end

    if !ytret
      # i.e.,, either not for testing or marshal-ed data are not found
      Rails.logger.debug("DEBUG: accesses Google/Youtube API for Video #{yid.inspect}")
      yt = youtube.list_videos(%w(snippet contentDetails), id: yid, hl: "en")  # maxResults is invalid with "id"
      ytret = ((yt && yt.items.present? && (yt.page_info.total_results > 0)) ? yt.items[0] : nil)
      # NOTE: yt is ALYWAS non-nil (== Google::Apis::YoutubeV3::...)
      #   @youtube.list_videos.items[0] returns nil or significant.
      #   However(!!), in the case of "list_channels" fails, if it fails to find one,
      #   it returns (@youtube.list_channels.items == nil) (!!)
      #   Here, for the video, "yt.items[0]" never fails at the time of writing (October 2024),
      #   the specification may change in the future?!
      #   So, to check it, it is safer to use +ret.page_info.total_results+

      msg = "DEBUG: Info of Video #{yid.inspect} was retrieved with Google/Youtube API; result=#{ytret.inspect}"
      Rails.logger.debug msg
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
  # @param set_instance_var: [Boolean] if true (Def), @yt_channel is set (possibly overwritten).
  # @return [Channel, NilClass]
  def get_channel(snippet, use_cache_test: false)
    channel = Channel.find_by(id_at_platform: snippet.channel_id)
    return _update_channel_youtube_ids(channel, snippet, set_instance_var: true) if channel

    get_yt_channel(snippet.channel_id, kind: :id_at_platform, set_instance_var: true) if !@yt_channel
    yt_handle = @yt_channel.snippet.custom_url

    channel = Channel.find_by(id_human_at_platform: yt_handle)
    return _update_channel_youtube_ids(channel, snippet, yt_handle: yt_handle) if channel

    ## preforming title-based search (may wrongly identifies Channel)
    chan_platform_youtube = ChannelPlatform.select_by_translations(en: {title: 'Youtube'}).first
    channel = Channel.where(channel_platform_id: chan_platform_youtube.id).select_regex(:title, /^#{Regexp.quote(snippet.channel_title)}(\b|\s|$)/, langcode: (snippet.default_language || "ja"), sql_regexp: true).joins(:channel_type).order("channel_types.weight").first  # based on the human-readable Channel title.  nil is returned if not found.
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

  # Assumes the Youtube title has the default language of Japanese and it may have English title but no others.
  #
  # If the default language is English, the existence of Japanese title is not checked.
  # Also, "en-GB" etc are not taken into account (though Youtube's fallback mechanism should work).
  #
  # @param snippet [#default_language, #localized] e.g., Google::Apis::YoutubeV3::ChannelSnippet
  # @return [Hash] e.g., {"ja" => "Some1", "en" => nil} (with_indifferent_access)
  def get_youtube_titles(snippet)
    # titles = {"ja" => nil, "en" => nil}.with_indifferent_access
    titles = {}.with_indifferent_access
    titles[(snippet.default_language || "ja")] = preprocess_space_zenkaku(snippet.title)
    
    if "en" == snippet.default_language || snippet.localized.title == snippet.title
      # do nothing
    else
      titles["en"] = preprocess_space_zenkaku(snippet.localized.title)
    end
    titles
  end


  # update or add {Channel#translations} or {HaramiVid#translations} according to Youtube.
  #
  # Translations of {Channel} or {HaramiVid} are always forcibly updated and are given the lowest (=best) weight.
  # If the existing best-translation has a weight of 0 and belongs to another user,
  # the translation is updated.  Otherwise, either the user's best translation is updated
  # or a new one with the lowest weight is created.
  #
  # @param snippet [#default_language, #localized] e.g., Google::Apis::YoutubeV3::ChannelSnippet
  # @param model: [ActiveRecord] Channel or HaramiVid
  # @return [String, NilClass]
  def adjust_youtube_titles(snippet, model: )
    raise if !current_user  # should never happen in normal calls.
    ret_msgs = []
    titles = get_youtube_titles(snippet)  # duplication is already eliminated if present. # defined in module_youtube_api_aux.rb
    [snippet.default_language, "ja", "en"].uniq.find_all(&:present?).each do |elc|  # snippet.default_language can be nil for some reason...
      next if titles[elc].blank?
      tras = model.translations.where(langcode: elc)
      next if tras.where(title: titles[elc]).or(tras.where(alt_title: titles[elc])).exists?  # Skip if an identical Translation exists whoever owns it.

      tra_best = model.best_translation(langcode: elc, fallback: false)
      tra0 = 
        if tra_best && tra_best.weight && tra_best.weight <= 0
          tra_best
        else
          tras.where(create_user_id: current_user.id).or(tras.where(update_user_id: current_user.id)).order(:weight).first
        end

      def_weight = Role::DEF_WEIGHT[Role::RNAME_MODERATOR]
      weight_updated =
        if !tra0
          ((tra_best && tra_best.weight) ? tra_best.weight/2.0 : def_weight)
        elsif (tra0.weight == tra_best.weight)
          ((!tra0.weight || tra0.weight > def_weight*10) ? def_weight : tra0.weight)
        elsif (tra0.weight > tra_best.weight)
          tra_best.weight/2.0
        else
          tra0.weight 
        end
      weight_updated = [weight_updated, def_weight, Translation.def_init_weight(current_user)].min

      if tra0
        tra = tra0
        result = tra.update(title: titles[elc], weight: weight_updated)
        ret_msgs << "Title[#{elc}] updated."
      else
        tra = Translation.preprocessed_new(title: titles[elc], langcode: elc, is_orig: (elc == (snippet.default_language || "ja")), weight: weight_updated)
        model.translations << tra
        ret_msgs << "New Title[#{elc}] added."
        result = tra.id  # Integer or nil if failed to save and associate.
      end

      if !result
        # Failed to save a Translation. The parent should rollback everything.
        msg_err = tra.errors.full_messages.join("; ") # +" / "+titles.inspect
        msg = [sprintf("ERROR: Failed to save a Translation[%s]: %s", elc, titles[elc]), msg_err].join(" / ")
        model.errors.add :base, msg
        return nil
      end
    end

    ret_msgs.join(" ")
  end

  # returns a new (unsaved) HaramiVid
  #
  # This routine does not care about potential duplication with existing records.
  # The caller should check with +HaramiVid.find_by_uri+
  #
  # If the Channel found is not registered in the DB, this routine either
  # returns immediately (if flash_on_error is false (Def)), or carries on
  # processing.  In either way, +HaramiVid#channel+ is set nil.  The caller
  # must handle it.
  #
  # This routine does nothing about EventItem or Music association.
  #
  # @note Caller should check and handles (1) whether it is on Youtube, (2) potential duplication
  #   on the existing HaramiVid (if new/create), (3) channel may be nil.
  #
  # @option harami_vid [HaramiVid]
  # @param uri: [String, NilClass] This can be given instead. If harami_vid is given and if its uri is blank?, this substitutes it.
  # @param place: [Place, NilClass] If specified, this is propagated to the new HaramiVid. Else, the default determination algorithm is adopted.
  # @param flash_on_error: [Boolean] If false (Def), if the Channel found is not registered in DB, this sets an error on the model (HaramiVid) and returns immediately. If true, this sets only a flash warning message and continues processing. Either way, the caller must take care of the Channel.
  # @return [HaramiVid, NilClass] nil if fails to get API. If Channel is not registered, HaramiVid#channel is nil. In either way, the given HaramiVid is desructively modified.
  def new_harami_vid_from_youtube_api(harami_vid=(@harami_vid || HaramiVid.new), uri: nil, place: nil, flash_on_error: false, use_cache_test: @use_cache_test)
    set_youtube  # sets @youtube
    harami_vid.uri = uri if uri.present? && harami_vid.uri.blank?
    get_yt_video(harami_vid, set_instance_var: true, model: true, use_cache_test: @use_cache_test) # sets @yt_video
    return if !@yt_video

    snippet = @yt_video.snippet
    get_yt_channel(snippet.channel_id, kind: :id_at_platform) # setting @yt_channel
    harami_vid.channel = _get_channel_maybe_set_error(snippet, harami_vid, flash_on_error: flash_on_error)
    return if !harami_vid.channel && !flash_on_error

    harami_vid.duration = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
    _adjust_date(snippet, harami_vid)

    titles, tras = _set_titles_translations(snippet, flash_on_error: flash_on_error)
    harami_vid.unsaved_translations = tras
    harami_vid.place = (place || self.class.guess_place(titles["ja"] || ""))

    flash[:notice] ||= []
    flash[:notice] << "Imported data from Youtube"
    harami_vid
  end

  #################
  private 
  #################


    # @param snippet
    # @param model [ActiveRecord] usually HaramiVid
    # @return [Channel, NilClass]
    def _get_channel_maybe_set_error(snippet, model, flash_on_error: false)
      channel = get_channel(snippet)  # @yt_channel must be set.
      _return_no_channel_err(snippet, model, flash_on_error: flash_on_error) if !channel
      channel
    end

    # Sets up an error or flash message
    #
    # Unless with_flash is given true, an error is set on the model,
    # which should raise an unprocessable error downstream.
    #
    # @param snippet
    # @param model [ActiveRecord, NilClass] as long as flash_on_error is false (Def), this is mandatory.  Error will be set.
    # @param flash_on_error: [Boolean] usually HaramiVid
    # @return [void]
    def _return_no_channel_err(snippet, model=nil, flash_on_error: false)
      msg_adjective = (flash_on_error ? "later" : "first")
      msg = sprintf("Channel is not found. Define the channel %s: ID=\"%s\", Name=\"%s\" [%s]", msg_adjective, snippet.channel_id, snippet.channel_title, (snippet.default_language || nil))
      if flash_on_error
        flash[:warning] ||= []
        flash[:warning] << msg
      else
        model.errors.add :base, msg
      end
      nil
    end

    # @param snippet
    # @param flash_on_error: [Boolean] If false (Def), this is for create. Else for new. Flash message are set accordingly if more than 1 Translation is registered on Youtube.
    # @return [Array<Array<String>, Array<Translation>>]
    def _set_titles_translations(snippet, flash_on_error: false)
      titles = get_youtube_titles(snippet)

      tras = []
      titles.each_pair do |lc, tit|
        next if tit.blank? || tit.strip.blank?
        tras << Translation.preprocessed_new(title: tit, langcode: lc.to_s, is_orig: (lc.to_s == snippet.default_language))
      end

      if (tras_size=tras.size) > 1
        severity, msg =
          if flash_on_error
            [:warning, sprintf("More than one (=%d) Translations are registered on Youtube, but only one of them is loaded so far. You may import them later after save.", tras_size)]
          else
            [:notice, sprintf("%d Translations are defined.", tras_size)]
          end
        flash[severity] ||= []
        flash[severity] << msg
      end

      [titles, tras]
    end

    # gets PrmChannelRemote from objects
    # @param yid [String, PrmChannelRemote, Channel]
    # @param kind: [String, Symbol] what yid means: either "id" or "forHandle"
    # @return [PrmChannelRemote, Array<PrmChannelRemote>] PrmChannelRemote or its 2-element Array
    def _get_pcr(yid, kind)
      if yid.respond_to?(:gsub)
        # String
        return PrmChannelRemote.new(yid, kind: kind)  # platform is Default.
      end

      if yid.respond_to?(:val) &&  yid.respond_to?(:kind)
        # PrmChannelRemote
        return yid if yid.kind.to_s == kind.to_s || yid.kind.to_sym != :unknown
        dup_pcr = yid.dup
        dup_pcr.update!(kind: kind.to_s)
        return dup_pcr
      end

      raise ArgumentError, "yid is strange. Contact the code developer. yid=#{yid.inspect}" if !yid.respond_to?(:id_at_platform)  # none of String, PrmChannelRemote, Channel

      retcand = %i(id_at_platform id_human_at_platform).map{|ek|
        (val=yid.send(ek)).present? ? PrmChannelRemote.new(val, kind: ek) : nil
      }.compact

      case retcand.size
      when 0
        raise "ERROR(#{File.basename __FILE__}): Channel given to get_yt_channel() has neither of :id_at_platform and :id_human_at_platform present."
      when 1
        retcand.first
      else
        retcand
      end
    end


    # Gets an Array of Youtube filter names (Symbols) for a Channel
    #
    # @param pcr [String, Symbol, PrmChannelRemote]
    # @return [Array<Symbol>]
    def _get_channel_filters(pcr)
      def_filters = %i(id for_handle)
      return def_filters if pcr.respond_to?(:gsub)

      case pcr.kind.to_sym
      when :unknown
        def_filters
      when *(KIND2YTFILTER.keys.map(&:to_sym))
        [KIND2YTFILTER[pcr.kind]]
      else
        raise "Unexpected kind=(#{pcr.kind.to_sym.inspect})"
      end
    end


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
    # @param set_instance_var: [Boolean] if true (Def), @yt_channel is set (possibly overwritten).
    # @return [Channel, NilClass]
    def _update_channel_youtube_ids(channel, snippet=nil, yt_handle: nil, set_instance_var: false)
      msg_err_head = sprintf("Failed to update Channel(pID=%d) for ", channel.id)
      get_yt_channel(snippet.channel_id, kind: :id_at_platform, set_instance_var: set_instance_var) if !@yt_channel
  
      if channel.id_at_platform != @yt_channel.id
        result = channel.update(id_at_platform: @yt_channel.id)
        ret = _run_update_channel(result, msg_err_head+"id_at_platform to: "+@yt_channel.id.inspect)
        return (ret ? channel : ret)
      end
 
      yt_handle ||= @yt_channel.snippet.custom_url
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

    def _adjust_date(snippet, model=@harami_vid)
      date = snippet.published_at.to_date # => DateTime
      if model.release_date != date
        model.release_date = date
        if !model.new_record?
          flash[:notice] ||= []
          flash[:notice] << "Release-Date is updated to #{date}"
        end
      end
    end

    # @param root_kwd [String] root filename for the marshal-led data.
    # @return [String, NilClass] The absolute path of the existing marshal file
    def _find_marshal_fullpath(root_kwd)
      get_fullpath_test_data(root_kwd, suffixes: %w(marshal))  # defined in application_helper.rb
    end


    # Returns a marshal-ed Youtube-Video object and its marshall fullpath (for potential use of updating later)
    #
    # Technically, it is possible to cache the results to avoid repeated loading.
    # However, this is used only for testing and only using the local machine power,
    # it would be too much.
    #
    # @param yid [String] Video ID at Youtube
    # @param data_kwds [String, Symbol, Array, NilClass] like :zenzenzense or its Array or nil (Def), in which case all defined in MARSHALED for the category (as defined in /test/helpers/marshaled.rb)
    # @param category [String, Symbol] either :video or :channel (or its String)
    # @param filters [Array<Symbol>] Considered only if category == :channel. What filters of Youtube should be used?
    # @return [Array<Google::Apis::YoutubeV3::Video,String,NilClass>] 2-element Array of [Apis|nil, String(full-path)|nil]
    def _get_youtube_marshaled_fullpath(yid, data_kwds=nil, category: :video, filters: [:id, :custom_url])
      return [nil, nil] if !is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL") && is_env_set_positive?("SKIP_YOUTUBE_MARSHAL")

      @marshal_abspaths ||= {}.with_indifferent_access
      @marshal_abspaths[category] ||= {}
      filters = [:id] if :video == category.to_sym 
      data_kwds ||= MARSHALED[:youtube][category].keys
      [data_kwds].flatten.each do |dkwd|
        next if !MARSHALED[:youtube][category][dkwd].slice(*filters).values.compact.include?(yid)

        @marshal_abspaths[category][dkwd] ||= _find_marshal_fullpath(MARSHALED[:youtube][category][dkwd][:basename])
        next if @marshal_abspaths[category][dkwd].blank?
        # fullpath = _find_marshal_fullpath(MARSHALED[:youtube][category][dkwd][:basename])
        # next if fullpath.blank?
        # Now, a file at fullpath is guaranteed to exist (never a new file).

        return [nil, @marshal_abspaths[category][dkwd]] if is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL") || is_env_set_positive?("SKIP_YOUTUBE_MARSHAL")

        Rails.logger.debug("DEBUG: loading marshall (kwd=#{dkwd.inspect}) for Video #{yid.inspect}")
        return [Marshal.load(IO.read(@marshal_abspaths[category][dkwd])), @marshal_abspaths[category][dkwd]]
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
      Rails.logger.info(msg)
      puts msg
      save_marshal(yt_vid, fullpath)  # defined in application_helper.rb
      return fullpath
    end

end
