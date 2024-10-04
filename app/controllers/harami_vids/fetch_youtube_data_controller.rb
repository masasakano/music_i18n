# coding: utf-8
# require "unicode/emoji"
# require "google/apis/youtube_v3"
#
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
class HaramiVids::FetchYoutubeDataController < ApplicationController
  include ApplicationHelper
  include HaramiVidsHelper # for set_event_event_items (common with HaramiVidsController)
  include ModuleYoutubeApiAux # defined in /app/models/concerns/module_youtube_api_aux.rb

  before_action :set_countries, only: [:create, :update] # defined in application_controller.rb

  # creates/edits a HaramiVid according to information fetched via Youtube API
  def create
    set_new_harami_vid  # set @harami_vid
    authorize! __method__, HaramiVid

    create_harami_vid_from_youtube_api  # unsaved_translations are added.
    result = def_respond_to_format(@harami_vid, render_err_path: "harami_vids")      # defined in application_controller.rb

    if result
      extra_str = sprintf(" / URI=<%s>", @harami_vid.uri)
      logger_after_create(@harami_vid, extra_str: extra_str, method_txt: __method__)  # defined in application_controller.rb
    end
#    result = def_respond_to_format(@harami_vid, created_updated: :created, back_html: "&ldquo;HaramiVid&rdquo; page") # defined in application_controller.rb
#
#    # Adjusts each Translation's update_user and updated_at if there is an equivalent user.
#    # These are not critical and so not included in DB-Transaction in the save above.
#    if result
#      @harami_vid.update_user_for_equivalent_harami_vid
#    end
  end

  # edits a HaramiVid according to information fetched via Youtube API
  def update
    set_harami_vid  # set @harami_vid
    authorize! __method__, @harami_vid

    ActiveRecord::Base.transaction(requires_new: true) do
      update_harami_vid_with_youtube_api
#begin
      result = def_respond_to_format(@harami_vid, :updated, render_err_path: "harami_vids")      # No update is run if @harami_vid.errors.any? ; defined in application_controller.rb
#  print "DEBUG:err-upd-225: "; p result
#rescue => er
#  print "DEBUG:err-upd-235: "; p er
#  raise
#end
    end
  end

  private
    # set @harami_vid from a given URL parameter
    def set_new_harami_vid
      @harami_vid = HaramiVid.new  # If returns nil below, this will eventually raise an ERROR with non-existtent URI
      safe_params = params.require(:harami_vid).require(:fetch_youtube_data).permit(:uri_youtube, :use_cache_test)
      @use_cache_test = get_bool_from_params(safe_params[:use_cache_test]) # defined in application_helper.rb
      uri = safe_params[:uri_youtube]
      return if uri.blank?
      @harami_vid = HaramiVid.new(uri: ApplicationHelper.uri_youtube(uri, with_http: false))
    end

    # set @harami_vid from a given URL parameter
    def set_harami_vid
      @harami_vid = nil
      safe_params = params.require(:harami_vid).require(:fetch_youtube_datum).permit(:use_cache_test)
      @use_cache_test = get_bool_from_params(safe_params[:use_cache_test]) # defined in application_helper.rb

      harami_vid_id = params[:id]
      return if harami_vid_id.blank?  # should never happen
      @harami_vid = HaramiVid.find(harami_vid_id)
      set_event_event_items  # sets @event_event_items  defined in harami_vids_helper.rb
    end

#    # set @youtube
#    def set_youtube
#      @youtube = Google::Apis::YoutubeV3::YouTubeService.new
#      @youtube.key = ENV["YOUTUBE_API_KEY"]  # or else
#      if @youtube.blank?
#        msg = "ERROR: ENV[YOUTUBE_API_KEY] undefined."
#        logger.error()
#        raise msg
#      end
#    end

    def create_harami_vid_from_youtube_api
      set_youtube  # sets @youtube
      get_yt_video(@harami_vid, set_instance_var: true, model: true, use_cache_test: @use_cache_test) # sets @yt_video # defined in module_youtube_api_aux.rb
      return if !@yt_video

      snippet = @yt_video.snippet
      get_yt_channel(snippet.channel_id, filter_kind: "id") # setting @yt_channel
      channel = get_channel(snippet)
      return _return_no_channel_err(snippet) if !channel

      @harami_vid.channel = channel
      @harami_vid.duration = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
      _adjust_date(snippet)

      _set_up_event_item_and_associate()  # setting EventItem association

      titles = _get_youtube_titles(snippet)
      tras = []
      titles.each_pair do |lc, tit|
        next if tit.blank? || tit.strip.blank?
        tras << Translation.preprocessed_new(title: tit, langcode: lc.to_s, is_orig: (lc.to_s == snippet.default_language))
      end
      @harami_vid.unsaved_translations = tras
    end

    # this is within a DB transaction (see {#update})
    def update_harami_vid_with_youtube_api
      set_youtube  # sets @youtube
      get_yt_video(@harami_vid, set_instance_var: true, model: true, use_cache_test: @use_cache_test) # sets @yt_video # defined in module_youtube_api_aux.rb
      return if !@yt_video

      #snippet = api.items[0].snippet
      snippet = @yt_video.snippet
      _check_and_set_channel(snippet)

      ret_msg = _adjust_youtube_titles(snippet)  # Translation(s) updated or created.
      return if ret_msg.blank?
      flash[:notice] ||= []
      flash[:notice] << ret_msg

      _adjust_date(snippet)

      duration_s = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
      if @harami_vid.duration != duration_s 
        @harami_vid.duration = duration_s 
        flash[:notice] << "Duration is updated to #{duration_s} [s]"
      end
    end

    # Save a new EventItem, imported from HaramiVidsController#set_up_event_item_and_associate
    #
    def _set_up_event_item_and_associate()
      evit = EventItem.new_default(:HaramiVid, event: Event.default(:HaramiVid), save_event: false)

      evit.update!(publish_date: @harami_vid.release_date)  # EventItem is always new, hence this is OK.

      @harami_vid.event_items << evit if !@harami_vid.event_items.include?(evit)
      @harami_vid.event_items.reset
    end

#    # Returns 2-element Array of @youtube.list_videos and fullpath, if recovering them from marshalled
#    #
#    # @param root_kwd [String] root filename for the marshal-led data.
#    # @return [Array<Hash,String,NilClass>] 2-element Array of [Hash(Google::Apis::YoutubeV3), String(full-path)] or [nil, nil]
#    def _get_youtuberet_fullpath(root_kwd)
#      return [nil, nil] if !@use_cache_test 
#
#      fullpath = get_fullpath_test_data(/^#{Regexp.quote(root_kwd)}/)  # defined in application_helper.rb
#      return [nil, nil] if !fullpath
#
#      [Marshal.load(IO.read(fullpath)), fullpath]
#    end

#    # Save the marshal-led Youtube-API-Hash if all the conditions satisfy.
#    #
#    # The data are saved if :
#    #
#    # * The given +fullpath+ is present, AND
#    # * +ENV["UPDATE_YOUTUBE_MARSHAL"]+ is set.
#    #
#    # @param hsdata [Hash] Youtube API return
#    # @param fullpath [String] to save.
#    # @return [String, NilClass>] If saved, the given fullpath is returned, else nil.
#    def _may_save_youtuberet_martial(hsdata, fullpath)
#      return nil if !(fullpath && is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL"))
#      open(fullpath, "w"){|io|
#        io.write(Marshal.dump(hsdata))
#      }
#      return fullpath
#    end
#
#    #
#    # If use_cache_test is specified and ENV["UPDATE_YOUTUBE_MARSHAL"] is set,
#    # the test data in /fixture/data is updated.
#    #
#    # @return [Google::Apis::YoutubeV3, NilClass] Youtube-API object or nil if the platform is not Youtube
#    def _get_youtube_api_videos
#      @id_youtube = ApplicationHelper.get_id_youtube_video(@harami_vid.uri)
#
#      if @id_youtube.respond_to?(:platform) && :youtube != @id_youtube.platform
#        @harami_vid.errors.add :base, "Non-Youtube video is unsupported."
#        return nil
#      end
#
#      part = "snippet"
#      hsret, fullpath = _get_youtuberet_fullpath(SEEDS_FBASE_YOUTUBE_ZENZENZENSE[part])
#
#      hsret ||= @youtube.list_videos("snippet", id: @id_youtube, hl: "en")  # maxResults is invalid with "id"
#      _may_save_youtuberet_martial(hsret, fullpath)
#      hsret
#    end
#
#    # Returns ActiveSupport::Duration of the Youtube video
#    #
#    # If use_cache_test is specified and ENV["UPDATE_YOUTUBE_MARSHAL"] is set,
#    # the test data in /fixture/data is updated.
#    #
#    # @return [ActiveSupport::Duration]
#    def _get_youtube_duration
#      part = "contentDetails"
#      hsret, fullpath = _get_youtuberet_fullpath(SEEDS_FBASE_YOUTUBE_ZENZENZENSE[part])
#
#      hsret ||= @youtube.list_videos(part, id: @id_youtube, hl: "en")  # duration etc.
#      _may_save_youtuberet_martial(hsret, fullpath)
#
#      # Duration is in ISO8601 format, e.g., "PT4M5S"
#      ActiveSupport::Duration.parse(hsret.items[0].content_details.duration)
#    end

    
#    # Sets @yt_channel
#    #
#    # It has 
#    # Sets @yt_channel (having attributes of "id" (=>ChannelID) and "snippet"
#    # (of Channel) and else) for "en".
#    # snippet has attributes of title, description, custom_url (=>@haramipiano_main),
#    # published_at (=>DateTime?), country (=>"JP"?), default_language (=>"ja"?),
#    # localized (=> {title:, description: } for "en" or its fallback.
#    #
#    # @return [Google::Apis::YoutubeV3::Channel, NilClass]
#    def _set_yt_channel(snippet)
#      @yt_channel = @youtube.list_channels("snippet", id: snippet.channel_id, hl: "en")
#      @yt_channel = @yt_channel.items[0]
#    end
#
#    def _run_update_channel(result, msg_err, msg_ok=nil)
#      flash[:notice] ||= []
#      if result
#        flash[:notice] << msg_ok if msg_ok
#        return result
#      end
#
#      @harami_vid.errors.add :base, msg_err
#      return result
#    end
#
#    # Updates Youtube-ID related info of the Channel
#    #
#    # Returns (parroting) the given Channel if everything is OK.
#    # If failed to update Channel when prompted to attempt, returns nil.
#    #
#    # @param channel [Channel]
#    # @param snippet [Google::Apis::YoutubeV3::Video, NilClass] unnecessary if @yt_channel is already set
#    # @param yt_handle: [String, NilClass] Youtube channel's Handle-name.
#    # @return [Channel, NilClass]
#    def _update_channel_youtube_ids(channel, snippet=nil, yt_handle: nil)
#      msg_err_head = sprintf("Failed to update Channel(pID=%d) for ", channel.id)
#      _set_yt_channel(snippet) if !@yt_channel
#
#      if channel.id_at_platform != @yt_channel.id
#        result = channel.update(id_at_platform: @yt_channel.id)
#        ret = _run_update_channel(result, msg_err_head+"id_at_platform to: "+@yt_channel.id.inspect)
#        return (ret ? channel : ret)
#      end
#
#      yt_handle ||= @yt_channel.snippet.custom_url.sub(/^@/, "")
#      if channel.id_human_at_platform != yt_handle
#        result = channel.update(id_human_at_platform: yt_handle)
#        ret = _run_update_channel(result, msg_err_head+"id_human_at_platform to: "+yt_handle.inspect)
#        return (ret ? channel : ret)
#      end
#
#      return channel
#    end
#
#    # Return the {Channel}
#    #
#    # If the ID-based search over the registered {Channel}-s has failed,
#    # a human-readable-ID-based search is performed. If it fails, a title-based search
#    # is performed.
#    #
#    # @return [Channel, NilClass]
#    def _get_channel(snippet)
#      channel = Channel.find_by(id_at_platform: snippet.channel_id)
#      return _update_channel_youtube_ids(channel, snippet) if channel
#
#      _set_yt_channel(snippet) if !@yt_channel
#      yt_handle = @yt_channel.snippet.custom_url.sub(/^@/, "")
#
#      channel = Channel.find_by(id_human_at_platform: yt_handle)
#      return _update_channel_youtube_ids(channel, snippet, yt_handle: yt_handle) if channel
#
#      ## preforming title-based search (may wrongly identifies Channel)
#      chan_platform_youtube = ChannelPlatform.select_by_translations(en: {title: 'Youtube'}).first
#      channel = Channel.where(channel_platform_id: chan_platform_youtube.id).select_regex(:title, /^#{Regexp.quote(snippet.channel_title)}(\b|\s|$)/, langcode: snippet.default_language, sql_regexp: true).joins(:channel_type).order("channel_types.weight").first  # based on the human-readable Channel title.  nil is returned if not found.
#      flash[:warning] ||= []
#
#      if !channel
#        msg = sprintf("Failed to find Channel with remote-IDs/handle (Youtube-ID=%s, Handle=%s).", 
#                      snippet.channel_id.inspect,
#                      yt_handle.inspect)
#        flash[:warning] << msg
#        return nil
#      end
#
#      id_defined = channel.id_at_platform.present? || channel.id_human_at_platform.present?
#      strmid, strtail =
#              if id_defined
#                ["inconsistent with those taken from the given URI", " Processing aborted."]
#              else
#                ["not defined", ""]
#              end
#      msg = sprintf("Although there is a Channel(pID=%s) [%s] with a similar name, its remote-IDs/handle are %s (Youtube-ID=%s, Handle=%s).%s", 
#                      channel.id.inspect,
#                      channel.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true),
#                      strmid,
#                      snippet.channel_id.inspect,
#                      yt_handle.inspect,
#                      strtail
#                   )
#      flash[:warning] << msg
#      return if id_defined
#
#      return _update_channel_youtube_ids(channel, snippet, yt_handle: yt_handle)
#    end

    # @return [NilClass]
    def _return_no_channel_err(snippet)
      msg = sprintf("Channel is not found. Define the channel first: ID=\"%s\", Name=\"%s\" [%s]", snippet.channel_id, snippet.channel_title, snippet.default_language)
      @harami_vid.errors.add :base, msg
      nil
    end

    # For update. @harami_vid.channel is set if possible.
    # @return [void]
    def _check_and_set_channel(snippet)
      channel = get_channel(snippet)
      if @harami_vid.channel && channel && @harami_vid.channel == channel
        # Fully consistent. do nothing
      elsif !@harami_vid.channel && channel
        @harami_vid.channel = channel
        logger.info "Channel (ID=#{channel.id}: #{channel.title}) is newly defined for HaramiVid (ID=#{@harami_vid.id})."
      else
        ch = @harami_vid.channel
        msg = sprintf("WARNING: The currently associated Channel (ID=%s: %s) to HaramiVid (ID=%d) is inconsistent with that (ID=%s) inferred from Youtube (ID=%s: %s)", (ch ? ch.id : "nil"), (ch ? ch.title_or_alt(lang_fallback_option: :either, article_to_head: true).inspect : '""'), @harami_vid.channel.id, (channel ? channel.id : "nil"), snippet.channel_id, snippet.channel_title)
        flash[:warning] ||= []
        flash[:warning] << msg
        logger.warn msg
      end
    end

    # Assumes the Youtube title has the default language of Japanese and it may have English title but no others.
    #
    # If the default language is English, the existence of Japanese title is not checked.
    # Also, "en-GB" etc are not taken into account (though Youtube's fallback mechanism should work).
    #
    # @return [Hash] e.g., {"ja" => "Some1", "en" => nil}
    def _get_youtube_titles(snippet)
      # titles = {"ja" => nil, "en" => nil}.with_indifferent_access
      titles = {}.with_indifferent_access
      titles[snippet.default_language] = preprocess_space_zenkaku(snippet.title)
      
      if "en" == snippet.default_language || snippet.localized.title == snippet.title
        # do nothing
      else
        titles["en"] = preprocess_space_zenkaku(snippet.localized.title)
      end
      titles
    end

    # Update or add {Channel.translations} according to Youtube.
    #
    # @return [String, NilClass]
    def _adjust_youtube_titles(snippet)
      raise if !current_user  # should never happen in normal calls.
      ret_msgs = []
      titles = _get_youtube_titles(snippet)  # duplication is already eliminated if present.
#print "DEBUG:err-upd-405: titles="; p titles
      [snippet.default_language, "ja", "en"].uniq.each do |elc|
        tras = @harami_vid.translations.where(langcode: elc)
#print "DEBUG:err-upd-424: lcode, def="; p [elc, snippet.default_language]
#print "DEBUG:err-upd-425: tras="; p tras
        next if tras.where(title: titles[elc]).or(tras.where(alt_title: titles[elc])).exists?  # Skip if an identical Translation exists whoever owns it.

        tra0 = tras.where(create_user_id: current_user.id).or(tras.where(update_user_id: current_user.id)).first
#print "DEBUG:err-upd-435: tra0="; p tra0
        if tra0 && diff_emoji_only?(tra0.title, titles[elc])  # defined in module_common.rb
          result = tra.update(title: titles[elc])
          ret_msgs << "Title[#{elc}] updated."
#print "DEBUG:err-upd-441: [result, tra]="; p [result, tra]
        else
          tra = Translation.preprocessed_new(title: titles[elc], langcode: elc, is_orig: (elc == snippet.default_language))
          @harami_vid.translations << tra
          ret_msgs << "New Title[#{elc}] added."
          result = tra.id  # Integer or nil if failed to save and associate.
#print "DEBUG:err-upd-446: [result, tra]="; p [result, tra]
        end

        if !result
          # Failed to save a Translation. The parent should rollback everything.
          msg = sprintf("ERROR: Failed to save a Translation[%s]: %s", elc, titles[elc])
          @harami_vid.errors.add :base, msg
          return nil
        end
      end

      ret_msgs.join(" ")
    end

    def _adjust_date(snippet)
      date = snippet.published_at.to_date # => DateTime
      if @harami_vid.release_date != date
        flash[:notice] ||= []
        flash[:notice] << "Release-Date is updated to #{date}"
        @harami_vid.release_date = date
      end
    end

end
